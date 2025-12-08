Feature: FR-36 Recurring Trip Dates
    Given an admin user "admin@example.com" with password "Password123!" exists

  Context: RecurringTripDatesContext

  @happy_path @positive
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

  @positive
  Scenario: Create trip with multiple comma-separated dates
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
      | dates               | 2025-12-05, 2025-12-12, 2025-12-19 |
    And I submit the trip form
    Then I should see a confirmation that the trip was created
    And I should see 3 dates for that trip

  @positive
  Scenario: Create trip with newline-separated dates
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with newline separated dates
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  @negative
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

  @negative
  Scenario: Create trip with invalid date format
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with invalid date format "not-a-date"
    And I submit the trip form
    Then I should see an error about invalid date format

  @edge_case
  Scenario: Create trip with duplicate dates (should deduplicate)
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with duplicate dates "2025-12-15, 2025-12-15, 2025-12-20"
    And I submit the trip form
    Then I should see a confirmation that the trip was created
    And I should see 2 dates for that trip

  @edge_case
  Scenario: Create trip with many dates
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with many dates
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  @edge_case
  Scenario: Create trip with mixed comma and newline separators
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with mixed date separators
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  # ========== INSTANCE MANAGEMENT SCENARIOS ==========

  @positive @instance_management
  Scenario: Admin successfully edits a trip instance date
    Given a trip with multiple dates exists
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the trip instances list
    And I select the first instance to edit
    And I change the instance date to "2025-12-20"
    And I submit the instance update
    Then I should see a confirmation that the instance was updated
    And the instance should have the new date

  @positive @instance_management
  Scenario: Admin successfully edits instance available tickets
    Given a trip with multiple dates exists
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the trip instances list
    And I select the first instance to edit
    And I change the available tickets to "75"
    And I submit the instance update
    Then I should see a confirmation that the instance was updated
    And the instance should have 75 available tickets

  @positive @instance_management
  Scenario: Admin successfully deletes a trip instance
    Given a trip with three dates exists
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the trip instances list
    And I delete the second instance
    Then I should see a confirmation that the instance was deleted
    And the trip should have 2 remaining dates

  @negative @instance_management
  Scenario: Cannot edit instance to duplicate date
    Given a trip with dates "2025-12-10" and "2025-12-15" exists
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the trip instances list
    And I select the first instance to edit
    And I change the instance date to "2025-12-15"
    And I submit the instance update
    Then I should see an error about duplicate date

  @negative @instance_management
  Scenario: Cannot edit instance to invalid date format
    Given a trip with multiple dates exists
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the trip instances list
    And I select the first instance to edit
    And I change the instance date to "invalid-date"
    And I submit the instance update
    Then I should see an error about invalid date format

  @edge_case @instance_management
  Scenario: Deleting instance from multi-date trip preserves other dates
    Given a trip with three dates exists
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the trip instances list
    And I delete the second instance
    Then the first and third instances should still exist
    And the trip should still be visible in the admin trips list
