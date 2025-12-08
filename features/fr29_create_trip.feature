Feature: FR-29 Create Trip

  Context: CreateTripContext

  Background:
    Given an admin user "admin@example.com" with password "Password123!" exists
    Given a regular user "user@example.com" with password "Password123!" exists

  @happy_path @positive
  Scenario: Successful creation of a basic trip
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a valid plane trip
    And I submit the trip form
    Then I should see a confirmation that the trip was created
    And I should see the trip listed in my future trips

  @positive
  Scenario: Create trip with bus transport mode
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a valid bus trip
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  @positive
  Scenario: Create trip with train transport mode
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a valid train trip
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  @positive
  Scenario: Create trip with minimum valid values
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with minimum values
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
    And I fill in a trip with long duration
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  @edge_case
  Scenario: Create trip with special characters in city names
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with special city names
    And I submit the trip form
    Then I should see a confirmation that the trip was created

  @edge_case
  Scenario: Create trip with large values
    When I log in as "admin@example.com" with password "Password123!"
    And I navigate to the admin trip creation page
    And I fill in a trip with large values
    And I submit the trip form
    Then I should see a confirmation that the trip was created
