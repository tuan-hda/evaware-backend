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


INSERT INTO api_paymentprovider(created_at, updated_at, is_deleted, img_url, name, method) VALUES('2023-05-30 09:49:34.220175+07', '2023-05-30 09:49:34.220175+07', false, 'https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Fvisa.png?alt=media&token=6f33f581-ac3a-4308-8dd3-3badd6d84110&_gl=1*15xjzlo*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTY1NjIuMC4wLjA.', 'Visa', 'Card');
INSERT INTO api_paymentprovider(created_at, updated_at, is_deleted, img_url, name, method) VALUES('2023-05-30 09:49:34.220175+07', '2023-05-30 09:49:34.220175+07', false, 'https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Fmastercard.png?alt=media&token=e27221d4-d12d-4653-9b73-00dd43227c97&_gl=1*1bqu0uz*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTY3NTguMC4wLjA.', 'Mastercard', 'Card');
INSERT INTO api_paymentprovider(created_at, updated_at, is_deleted, img_url, name, method) VALUES('2023-05-30 09:49:34.220175+07', '2023-05-30 09:49:34.220175+07', false, 'https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Fjcb.png?alt=media&token=63161821-0dd9-4a0a-b7e9-98d21085bd17&_gl=1*1uampi0*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTY5NDkuMC4wLjA.', 'JCB', 'Card');
INSERT INTO api_paymentprovider(created_at, updated_at, is_deleted, img_url, name, method) VALUES('2023-05-30 09:49:34.220175+07', '2023-05-30 09:49:34.220175+07', false, 'https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Famerican_express.png?alt=media&token=89ed60a2-d479-4f58-9b3c-3dbb592b09da&_gl=1*1bt6mtu*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTY5OTcuMC4wLjA.', 'American Express', 'Card');
INSERT INTO api_paymentprovider(created_at, updated_at, is_deleted, img_url, name, method) VALUES('2023-05-30 09:49:34.220175+07', '2023-05-30 09:49:34.220175+07', false, 'https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Fmomo.png?alt=media&token=c5b60b50-81b6-47b1-b887-383e8ade7690&_gl=1*y1rmcs*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTcyMTAuMC4wLjA.', 'Momo', 'E-Wallet');
INSERT INTO api_paymentprovider(created_at, updated_at, is_deleted, img_url, name, method) VALUES('2023-05-30 09:49:34.220175+07', '2023-05-30 09:49:34.220175+07', false, 'https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Fatm.png?alt=media&token=185e3eb1-b48b-4c35-80d6-7a1f016c5d88&_gl=1*ixz4m9*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTcyNjQuMC4wLjA.', 'ATM', 'Domestic ATM Card');
