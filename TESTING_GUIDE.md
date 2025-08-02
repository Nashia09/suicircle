# Access Control System Testing Guide

## Overview

This guide provides comprehensive testing procedures for the access control system implementation. Follow these steps to validate all functionality before deployment.

## Prerequisites

1. **Backend Server**: Running on `http://localhost:3000`
2. **Frontend Application**: Running on `http://localhost:3001` (or your configured port)
3. **Test Mode**: Enabled for initial testing (no smart contract required)
4. **Authentication**: Working zkLogin or test authentication

## Test Scenarios

### 1. Basic Access Control Creation

#### Test Case 1.1: Email-based Access Control

**Steps:**
1. Upload a test file through the frontend
2. Click the "Access Control" button on the file
3. Select "Email" tab
4. Add email addresses: `test1@example.com`, `test2@example.com`
5. Click "Create Access Control"

**Expected Results:**
- Success message displayed
- Access control created with transaction digest
- File shows access control status badge

**API Test:**
```bash
curl -X POST http://localhost:3000/access-control/test \
  -H "Content-Type: application/json" \
  -d '{
    "fileCid": "test-file-cid",
    "accessRule": {
      "conditionType": "email",
      "allowedEmails": ["test1@example.com", "test2@example.com"]
    }
  }'
```

#### Test Case 1.2: Wallet-based Access Control

**Steps:**
1. Select "Wallet" tab in access control dialog
2. Add wallet addresses: `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`
3. Click "Create Access Control"

**Expected Results:**
- Wallet addresses validated and accepted
- Access control created successfully

#### Test Case 1.3: Time-based Access Control

**Steps:**
1. Select "Time" tab
2. Set access start time: Current time + 1 hour
3. Set access end time: Current time + 24 hours
4. Set max access duration: 60 minutes
5. Set max access count: 10
6. Click "Create Access Control"

**Expected Results:**
- Time validation passes
- Access control created with time restrictions

#### Test Case 1.4: Hybrid Access Control

**Steps:**
1. Select "Hybrid" tab
2. Add both email addresses and wallet addresses
3. Set time restrictions
4. Toggle "Require ALL conditions" switch
5. Click "Create Access Control"

**Expected Results:**
- All conditions properly configured
- Logic setting (AND/OR) correctly applied

### 2. Access Control Validation

#### Test Case 2.1: Valid Access

**Steps:**
1. Create email-based access control with your email
2. Attempt to download the file
3. Check access control logs

**Expected Results:**
- File download succeeds
- Access granted event logged
- User access record created

**API Test:**
```bash
curl -X POST http://localhost:3000/access-control/validate-test \
  -H "Content-Type: application/json" \
  -d '{
    "fileCid": "test-file-cid",
    "userAddress": "0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef",
    "userEmail": "test1@example.com"
  }'
```

#### Test Case 2.2: Access Denied - Email Not Allowed

**Steps:**
1. Create email-based access control with `allowed@example.com`
2. Try to access with `denied@example.com`
3. Verify access is denied

**Expected Results:**
- Access denied message
- File download blocked
- Access denied event logged

#### Test Case 2.3: Access Denied - Time Restrictions

**Steps:**
1. Create time-based access control with future start time
2. Attempt immediate access
3. Verify access is denied

**Expected Results:**
- Access denied due to time restrictions
- Appropriate error message displayed

### 3. Access Control Updates

#### Test Case 3.1: Update Existing Access Control

**Steps:**
1. Create initial access control
2. Click "Access Control" button again
3. Modify settings (add/remove emails, change time restrictions)
4. Click "Update Access Control"

**Expected Results:**
- Existing access control updated
- New settings take effect immediately
- Update transaction recorded

#### Test Case 3.2: Change Access Control Type

**Steps:**
1. Create email-based access control
2. Update to hybrid access control
3. Add wallet and time restrictions
4. Save changes

**Expected Results:**
- Access control type successfully changed
- All new restrictions applied
- Previous restrictions cleared appropriately

### 4. UI Component Testing

#### Test Case 4.1: Access Control Status Display

**Steps:**
1. Create various types of access control
2. Verify status badges display correctly
3. Check detailed view functionality

**Expected Results:**
- Correct access control type badges
- Accurate access count display
- Detailed information shows all settings

#### Test Case 4.2: Access Control Configuration Dialog

**Steps:**
1. Test all form inputs
2. Verify validation messages
3. Test form submission and cancellation

**Expected Results:**
- All form fields work correctly
- Validation prevents invalid inputs
- Dialog closes appropriately

### 5. Error Handling

#### Test Case 5.1: Invalid Email Format

**Steps:**
1. Enter invalid email: `invalid-email`
2. Attempt to create access control

**Expected Results:**
- Validation error displayed
- Form submission blocked
- Clear error message shown

#### Test Case 5.2: Invalid Wallet Address

**Steps:**
1. Enter invalid wallet address: `0x123` (too short)
2. Attempt to create access control

**Expected Results:**
- Address validation fails
- Error message explains format requirements

#### Test Case 5.3: Invalid Time Range

**Steps:**
1. Set end time before start time
2. Attempt to create access control

**Expected Results:**
- Time validation error
- Clear explanation of the issue

### 6. Integration Testing

#### Test Case 6.1: File Service Integration

**Steps:**
1. Create access control for a file
2. Attempt file download through normal file service
3. Verify access control is enforced

**Expected Results:**
- File service respects access control rules
- Access validation occurs before file access
- Proper error handling for denied access

#### Test Case 6.2: Authentication Integration

**Steps:**
1. Test access control with authenticated users
2. Test with unauthenticated requests
3. Verify token validation

**Expected Results:**
- Authentication required for all operations
- Proper token validation
- Appropriate error responses for invalid tokens

### 7. Performance Testing

#### Test Case 7.1: Multiple Access Control Rules

**Steps:**
1. Create access control with many email addresses (50+)
2. Create access control with many wallet addresses (50+)
3. Test validation performance

**Expected Results:**
- Reasonable response times (<1 second)
- No memory issues
- Proper handling of large rule sets

#### Test Case 7.2: Concurrent Access Validation

**Steps:**
1. Simulate multiple users accessing the same file simultaneously
2. Monitor access count accuracy
3. Check for race conditions

**Expected Results:**
- Accurate access counting
- No race conditions
- Consistent validation results

## Automated Testing

### Backend Unit Tests

Create tests for:
- Access rule validation logic
- Time-based access calculations
- Email and address format validation
- Access control service methods

### Frontend Component Tests

Create tests for:
- Access control configuration component
- Access control status component
- Form validation logic
- API service integration

### Integration Tests

Create tests for:
- End-to-end access control workflows
- File service integration
- API endpoint functionality

## Test Data

### Sample Email Addresses
- `test1@example.com`
- `test2@example.com`
- `admin@company.com`
- `user@domain.org`

### Sample Wallet Addresses
- `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`
- `0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890`
- `0x9876543210fedcba9876543210fedcba9876543210fedcba9876543210fedcba`

### Sample File CIDs
- `QmTest1234567890abcdef`
- `QmSample9876543210fedcba`
- `QmExample1111222233334444`

## Troubleshooting

### Common Issues

1. **CORS Errors**: Ensure backend CORS is configured for frontend domain
2. **Authentication Failures**: Verify token format and expiration
3. **Validation Errors**: Check input formats match requirements
4. **Time Zone Issues**: Ensure consistent time handling across components

### Debug Commands

```bash
# Check backend logs
docker logs suicircle-backend

# Test API endpoints directly
curl -X GET http://localhost:3000/access-control/test-file-cid/test

# Verify frontend console for errors
# Open browser developer tools and check console
```

## Test Completion Checklist

- [ ] All basic access control types work (email, wallet, time, hybrid)
- [ ] Access validation correctly grants/denies access
- [ ] Access control updates function properly
- [ ] UI components display correctly
- [ ] Error handling works for all invalid inputs
- [ ] File service integration enforces access control
- [ ] Authentication integration works properly
- [ ] Performance is acceptable under load
- [ ] All API endpoints respond correctly
- [ ] Frontend components handle all states properly

## Reporting Issues

When reporting issues, include:
1. **Test case being executed**
2. **Expected vs actual results**
3. **Error messages or logs**
4. **Browser/environment details**
5. **Steps to reproduce**

---

**Testing Status**: Ready for execution
**Last Updated**: 2025-07-26
**Version**: 1.0.0
