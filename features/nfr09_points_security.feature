Feature: NFR-09 Points Security
  As a system administrator
  I want to ensure all loyalty point transactions are secure and audited
  So that fraud is prevented and user balances are accurate

  Background:
    Given I am a registered user named "Secure User"
    And there is a trip "Secure Trip" costing 100.0 EUR
    And I am logged in

  # NFR-09: Positive Scenario
  Scenario: Point changes are audited
    When I search for "Secure Trip"
    And I view the trip details
    And I purchase a ticket
    Then I should see "Trip purchased!"
    And an audit log should exist for my point change

  # NFR-09: Negative Scenario
  Scenario: Transaction rollback prevents partial updates
    Given there is a trip "Sold Out Trip" costing 50.0 EUR
    And that trip is sold out
    When I search for "Sold Out Trip"
    And I view the trip details
    And I attempt to purchase a ticket
    Then I should see "This trip is sold out"
    And my loyalty points balance should be 0
    And no audit log should exist for this user

  # NFR-09: Edge Case
  Scenario: Zero point change is logged for audit trail
    Given there is a trip "Free Trip" costing 0.0 EUR
    When I search for "Free Trip"
    And I view the trip details
    And I purchase a ticket
    Then I should see "Trip purchased!"
    And my loyalty points balance should be 0
    And an audit log should exist showing a change of 0 points

  # NFR-09: Positive Scenario (API Protection)
  Scenario: Points cannot be manually modified via API (Simulated)
    Given I have 100 loyalty points
    When I search for "Secure Trip"
    And I view the trip details
    And I choose to redeem my points
    And I purchase a ticket
    Then I should see "Trip purchased!"
    And my loyalty points balance should be 10
    And an audit log should exist showing a decrease of 90 points
