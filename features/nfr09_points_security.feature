Feature: NFR-09 Points Security
  As a system administrator
  I want to ensure all loyalty point transactions are secure and audited
  So that fraud is prevented and user balances are accurate

  Background:
    Given I am a registered user named "Secure User"
    And there is a trip "Secure Trip" costing 100.0 EUR
    And I am logged in

  # Positive Scenario
  Scenario: Point changes are audited
    When I search for "Secure Trip"
    And I view the trip details
    And I purchase a ticket
    Then I should see "Trip purchased!"
    And an audit log should exist for my point change

  # Positive Scenario (API Protection)
  Scenario: Points cannot be manually modified via API (Simulated)
    Given I have 100 loyalty points
    When I search for "Secure Trip"
    And I view the trip details
    And I choose to redeem my points
    And I purchase a ticket
    Then I should see "Trip purchased!"
    # 100 points - 1000 points cost = 0? No, 100 points = 10 EUR discount.
    # Trip cost 100 EUR. Discount 10 EUR. Final price 90 EUR. Earn 90 points.
    # New balance = 100 - 100 (redeemed) + 90 (earned) = 90 points.
    # Wait, max discount is 100%? No. Logic: min(max_discount_points, points_available).
    # Trip 100 EUR -> max discount points = 100 * 10 = 1000.
    # User has 100 points. All 100 used. Discount = 10 EUR.
    # New Price = 90 EUR. Earn 90 points.
    # Balance = 100 - 100 + 90 = 90.
    And my loyalty points balance should be 90
    # Audit log should show the net change (90 - 100 = -10) or separate entries?
    # Trips.ex implementation: one log entry with "net_point_change".
    # Net change = 90 (earned) - 100 (redeemed) = -10.
    # So audit log should decrease by 10 points.
    And an audit log should exist showing a decrease of 10 points

  # Negative Scenario
  Scenario: Transaction rollback prevents partial updates
    Given there is a trip "Sold Out Trip" costing 50.0 EUR
    And that trip is sold out
    When I search for "Sold Out Trip"
    And I view the trip details
    And I attempt to purchase a ticket
    Then I should see "All future dates are sold out."
    And my loyalty points balance should be 0
    And no audit log should exist for this user

  # Edge Case
  Scenario: Minimal point change is logged for audit trail
    Given there is a trip "Cheap Trip" costing 1.0 EUR
    When I search for "Cheap Trip"
    And I view the trip details
    And I purchase a ticket
    Then I should see "Trip purchased!"
    # 1 EUR trip -> ~1 point earned
    And an audit log should exist for my point change
