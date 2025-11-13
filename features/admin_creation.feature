Feature: Admin account creation
  As an existing admin
  I want to create new admin accounts
  So that other admins can manage the system

  Background:
    Given I am logged in as an admin

  Scenario: Successfully create a new admin
    When I visit the admin creation page
    And I fill the admin creation form with valid data
    And I submit the admin creation form
    Then I should see a success message "Admin created successfully"

  Scenario: Fail to create admin with missing fields
    When I visit the admin creation page
    And I submit the admin creation form with incomplete data
    Then I should see an admin creation error
