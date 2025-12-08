Feature: Admin account creation (FR-02)
  As an existing admin
  I want to create new admin accounts
  So that other admins can manage the system

  Background:
    Given I am logged in as an admin

  # ========== POSITIVE CASES ==========
  
  Scenario: Successfully create a new admin
    When I visit the admin creation page
    And I fill the admin creation form with valid data
    And I submit the admin creation form
    Then I should see a success message "Admin created successfully"
    And the new admin should be able to log in

  # ========== NEGATIVE CASES ==========

  Scenario: Fail to create admin with missing username
    When I visit the admin creation page
    And I leave the username field empty
    And I submit the admin creation form
    Then I should see an admin creation error
    And I should see "can't be blank"

  Scenario: Fail to create admin with missing email
    When I visit the admin creation page
    And I leave the email field empty
    And I submit the admin creation form
    Then I should see an admin creation error

  Scenario: Fail to create admin with invalid email format
    When I visit the admin creation page
    And I enter an invalid email format
    And I submit the admin creation form
    Then I should see an admin creation error

  Scenario: Fail to create admin with duplicate email
    Given an admin with email "duplicate@example.com" exists
    When I visit the admin creation page
    And I try to create admin with email "duplicate@example.com"
    And I submit the admin creation form
    Then I should see an admin creation error
    And I should see "has already been taken"

  Scenario: Fail to create admin with password too short
    When I visit the admin creation page
    And I enter a password shorter than 8 characters
    And I submit the admin creation form
    Then I should see an admin creation error

  Scenario: Fail to create admin with mismatched passwords
    When I visit the admin creation page
    And I enter mismatched password confirmation
    And I submit the admin creation form
    Then I should see an admin creation error
    And I should see "does not match"

  Scenario: Regular user cannot access admin creation page
    Given I am logged out
    And I am logged in as a regular user
    When I try to visit the admin creation page
    Then I should be redirected to the home page
    And I should see "Not allowed."

  Scenario: Non-admin cannot create admin accounts
    Given I am logged out
    And I am logged in as a regular user
    When I try to create an admin via direct API call
    Then the request should be unauthorized