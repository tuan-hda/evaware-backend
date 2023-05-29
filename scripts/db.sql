CREATE OR REPLACE FUNCTION update_reviews_count()
RETURNS TRIGGER AS $$
DECLARE
  p_id INTEGER;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT product_id INTO p_id FROM api_variation WHERE id = NEW.variation_id;
	UPDATE api_product
    SET reviews_count = reviews_count + 1
    WHERE id = p_id;
  ELSIF TG_OP = 'DELETE' THEN
    SELECT product_id INTO p_id FROM api_variation WHERE id = OLD.variation_id;
	UPDATE api_product
    SET reviews_count = reviews_count - 1
    WHERE id = p_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_reviews_count_trigger
AFTER INSERT OR DELETE ON review
FOR EACH ROW
EXECUTE FUNCTION update_reviews_count();