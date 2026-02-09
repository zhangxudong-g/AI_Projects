CREATE PROCEDURE get_user(IN p_id INT)
BEGIN
  SELECT * FROM users WHERE id = p_id;
END;