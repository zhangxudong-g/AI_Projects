-- ============================================================================
-- PL/SQL Test Sample for Parser Demo
-- Contains package specification, package body with procedures and functions
-- ============================================================================

-- Package Specification: USER_UTILS_PKG
-- Purpose: Utility functions and procedures for user management
-- Author: Demo Author
-- Created: 2024-01-15
CREATE OR REPLACE PACKAGE USER_UTILS_PKG AS
    -- ============================================================================
    -- Function: validate_email
    -- Description: Validates an email address format
    -- Parameters:
    --   p_email - The email address to validate (VARCHAR2)
    -- Returns:
    --   BOOLEAN - TRUE if valid, FALSE otherwise
    -- Example:
    --   IF USER_UTILS_PKG.validate_email('user@example.com') THEN
    --       DBMS_OUTPUT.PUT_LINE('Valid email');
    --   END IF;
    -- ============================================================================
    FUNCTION validate_email(
        p_email IN VARCHAR2
    ) RETURN BOOLEAN;

    -- ============================================================================
    -- Procedure: generate_user_id
    -- Description: Generates a unique user ID based on timestamp and random sequence
    -- Parameters:
    --   p_prefix - Optional prefix for the user ID (default: 'USR')
    --   p_user_id - OUT parameter containing the generated user ID
    -- Example:
    --   DECLARE
    --       v_user_id VARCHAR2(50);
    --   BEGIN
    --       USER_UTILS_PKG.generate_user_id('ADMIN', v_user_id);
    --       DBMS_OUTPUT.PUT_LINE('Generated ID: ' || v_user_id);
    --   END;
    -- ============================================================================
    PROCEDURE generate_user_id(
        p_prefix IN VARCHAR2 DEFAULT 'USR',
        p_user_id OUT VARCHAR2
    );

    -- ============================================================================
    -- Function: get_user_by_id
    -- Description: Retrieves user information by user ID
    -- Parameters:
    --   p_user_id - The user ID to search for
    -- Returns:
    --   SYS_REFCURSOR - Cursor containing user record
    -- ============================================================================
    FUNCTION get_user_by_id(
        p_user_id IN VARCHAR2
    ) RETURN SYS_REFCURSOR;

    -- ============================================================================
    -- Procedure: update_user_status
    -- Description: Updates the status of a user account
    -- Parameters:
    --   p_user_id - The user ID to update
    --   p_status - New status value ('ACTIVE', 'INACTIVE', 'SUSPENDED')
    --   p_updated_by - User performing the update
    -- ============================================================================
    PROCEDURE update_user_status(
        p_user_id IN VARCHAR2,
        p_status IN VARCHAR2,
        p_updated_by IN VARCHAR2
    );

END USER_UTILS_PKG;
/

-- Package Body: USER_UTILS_PKG
-- Implementation of all package functions and procedures
CREATE OR REPLACE PACKAGE BODY USER_UTILS_PKG AS

    -- Private constant for email validation pattern
    C_EMAIL_PATTERN CONSTANT VARCHAR2(100) := '%_@__%.__%';

    -- ============================================================================
    -- Function: validate_email (Implementation)
    -- Validates email format using pattern matching
    -- ============================================================================
    FUNCTION validate_email(
        p_email IN VARCHAR2
    ) RETURN BOOLEAN IS
    BEGIN
        -- Check if email is null
        IF p_email IS NULL THEN
            RETURN FALSE;
        END IF;

        -- Check if email matches basic pattern
        IF p_email LIKE C_EMAIL_PATTERN THEN
            -- Additional validation: no spaces allowed
            IF INSTR(p_email, ' ') > 0 THEN
                RETURN FALSE;
            END IF;
            
            -- Additional validation: must have valid characters
            IF REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
                RETURN TRUE;
            ELSE
                RETURN FALSE;
            END IF;
        ELSE
            RETURN FALSE;
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            -- Log error and return false
            DBMS_OUTPUT.PUT_LINE('Error in validate_email: ' || SQLERRM);
            RETURN FALSE;
    END validate_email;

    -- ============================================================================
    -- Procedure: generate_user_id (Implementation)
    -- Generates unique user ID with timestamp and random component
    -- ============================================================================
    PROCEDURE generate_user_id(
        p_prefix IN VARCHAR2 DEFAULT 'USR',
        p_user_id OUT VARCHAR2
    ) IS
        v_timestamp VARCHAR2(20);
        v_random VARCHAR2(10);
    BEGIN
        -- Generate timestamp component: YYYYMMDDHHMMSS
        v_timestamp := TO_CHAR(SYSDATE, 'YYYYMMDDHH24MISS');
        
        -- Generate random 4-digit number
        v_random := LPAD(TRUNC(DBMS_RANDOM.VALUE(0, 9999)), 4, '0');
        
        -- Combine prefix, timestamp and random
        p_user_id := p_prefix || '_' || v_timestamp || '_' || v_random;
        
        -- Log generation
        DBMS_OUTPUT.PUT_LINE('Generated user ID: ' || p_user_id);

    EXCEPTION
        WHEN OTHERS THEN
            -- Log error and raise
            DBMS_OUTPUT.PUT_LINE('Error in generate_user_id: ' || SQLERRM);
            RAISE;
    END generate_user_id;

    -- ============================================================================
    -- Function: get_user_by_id (Implementation)
    -- Returns user record as ref cursor
    -- ============================================================================
    FUNCTION get_user_by_id(
        p_user_id IN VARCHAR2
    ) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT 
                user_id,
                username,
                email,
                status,
                created_date,
                updated_date,
                updated_by
            FROM users
            WHERE user_id = p_user_id;
        
        RETURN v_cursor;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('User not found: ' || p_user_id);
            RETURN NULL;
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error in get_user_by_id: ' || SQLERRM);
            RAISE;
    END get_user_by_id;

    -- ============================================================================
    -- Procedure: update_user_status (Implementation)
    -- Updates user status with audit trail
    -- ============================================================================
    PROCEDURE update_user_status(
        p_user_id IN VARCHAR2,
        p_status IN VARCHAR2,
        p_updated_by IN VARCHAR2
    ) IS
        v_valid_status BOOLEAN;
    BEGIN
        -- Validate status value
        v_valid_status := p_status IN ('ACTIVE', 'INACTIVE', 'SUSPENDED');
        
        IF NOT v_valid_status THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'Invalid status value: ' || p_status || '. Must be ACTIVE, INACTIVE, or SUSPENDED'
            );
        END IF;
        
        -- Update user status
        UPDATE users
        SET 
            status = p_status,
            updated_date = SYSDATE,
            updated_by = p_updated_by
        WHERE user_id = p_user_id;
        
        -- Check if user was found
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(
                -20002,
                'User not found: ' || p_user_id
            );
        END IF;
        
        -- Commit the change
        COMMIT;
        
        DBMS_OUTPUT.PUT_LINE('User ' || p_user_id || ' status updated to ' || p_status);

    EXCEPTION
        WHEN OTHERS THEN
            -- Rollback on error
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error in update_user_status: ' || SQLERRM);
            RAISE;
    END update_user_status;

END USER_UTILS_PKG;
/
