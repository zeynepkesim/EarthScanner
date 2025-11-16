@test
Feature: Admin views future trips (FR-31)
  As an admin
  I want to view all my future trips
  So that I can manage upcoming trips and their details

  Scenario: Admin sees future trips page header
    Given I am logged in as an admin
    When I visit the future trips page
    Then I should see the future trips heading

  Scenario: Admin sees seeded future trip
    Given I am logged in as an admin
    When I visit the future trips page
    Then I should see a future trip in the list

  Scenario: Regular user cannot access admin future trips
    Given I am logged in as a normal user
    When I visit the future trips page
    Then I should see the login page
