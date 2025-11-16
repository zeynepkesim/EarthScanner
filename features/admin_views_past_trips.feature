@test
Feature: Admin views past trips (FR-30)
  As an admin
  I want to view all my past trips
  So that I can review completed trips and their details

  Scenario: Admin sees past trips page header
    Given I am logged in as an admin
    When I visit the past trips page
    Then I should see the past trips heading

  Scenario: Admin sees seeded past trip
    Given I am logged in as an admin
    When I visit the past trips page
    Then I should see a past trip in the list

  Scenario: Regular user cannot access admin past trips
    Given I am logged in as a normal user
    When I visit the past trips page
    Then I should see the login page
