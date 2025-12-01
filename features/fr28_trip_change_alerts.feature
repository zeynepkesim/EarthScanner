Feature: FR-28 Trip Change Alerts
  As an admin who edits a trip, I want purchasers to be alerted immediately

  Scenario: Purchasers receive an in-app notification after admin edits a trip
    Given a trip exists
    And a normal user has purchased a ticket for that trip
    When I am logged in as that normal user
    And the admin updates the trip price
    Then I should see a trip change notification mentioning the updated price

  Scenario: Non-purchaser does not receive a trip change notification
    Given a trip exists
    And I am logged in as a normal user
    When the admin updates the trip price
    Then I should not see a trip change notification mentioning the updated price
