Feature: FR-12 Purchase Trip Ticket
  # nfr-08: BDD - ensures authentication is required for purchase flows (positive and negative scenarios)
  As a traveler
  I want to purchase a ticket for a trip date
  So that I can reserve my seat for an upcoming journey.

  Scenario: Logged in user purchases an available trip instance
    Given I am logged in as a normal user
    And a future trip with available tickets exists
    When I visit that trip's detail page
    And I purchase the first available date
    Then I should see a purchase confirmation message

  Scenario: Guest must log in before purchasing
    Given I am not logged in
    And a future trip with available tickets exists
    When I visit that trip's detail page
    And I attempt to purchase the first available date
    Then I should see a login required message

  Scenario: Logged in user cannot purchase the same trip twice
    Given I am logged in as a normal user
    And a future trip with available tickets exists
    And I have already purchased that trip date
    When I visit that trip's detail page
    And I purchase the first available date
    Then I should see an already purchased message
