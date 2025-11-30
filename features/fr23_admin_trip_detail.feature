Feature: Admin trip detail access (FR-23)
  In order to protect trip data
  As an admin
  I want to ensure only the creating admin can view trip details

  Scenario: Creator admin can view their trip details
    Given I am logged in as an admin who created a trip
    When I visit the admin trip detail page for that trip
    Then I should see the trip's source and destination on the page

  Scenario: Non-creator admin cannot view another admin's trip
    Given I am logged in as an admin who did NOT create the trip
    When I visit the admin trip detail page for that trip
    Then I should see an unauthorized message or be redirected to the admin trips list
