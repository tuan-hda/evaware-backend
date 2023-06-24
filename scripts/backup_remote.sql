--
-- PostgreSQL database dump
--

-- Dumped from database version 15.2
-- Dumped by pg_dump version 15.3 (Ubuntu 15.3-1.pgdg22.04+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: examify_pxac_user
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO examify_pxac_user;

--
-- Name: check_answer(integer, integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.check_answer(arg_examtaking_id integer, arg_question_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		var_user_answer int;
		var_correct_answer int;
	BEGIN		
		SELECT choice_id INTO var_user_answer
		FROM answer_record 
		WHERE exam_taking_id = arg_examtaking_id
		AND question_id = arg_question_id;
		
		SELECT choice_id INTO var_correct_answer
		FROM choice
		WHERE question_id = arg_question_id
		AND key = true;
		
-- 		Check user answer and correct answer: (0: wrong, 1: correct, 2: user don't filled)
		IF var_user_answer = var_correct_answer 
			THEN return 1;
		ELSE 
			IF var_user_answer <> var_correct_answer 
				THEN return 0;
			ELSE 
				return 2;
			END IF;
		END IF;
	END;
$$;


ALTER FUNCTION public.check_answer(arg_examtaking_id integer, arg_question_id integer) OWNER TO examify_pxac_user;

--
-- Name: check_completed_lesson(integer, integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.check_completed_lesson(arg_user_id integer, arg_lesson_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		completed boolean;
	BEGIN		
		SELECT CASE WHEN COUNT(*) = 0 THEN false ELSE true END INTO completed
		FROM join_lesson
		WHERE student_id = arg_user_id
		AND lesson_id = arg_lesson_id;

		RETURN completed;
	END;
$$;


ALTER FUNCTION public.check_completed_lesson(arg_user_id integer, arg_lesson_id integer) OWNER TO examify_pxac_user;

--
-- Name: check_flashcard_permission(integer, integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.check_flashcard_permission(arg_user_id integer, arg_fc_set_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		isAllow boolean;
	BEGIN
		SELECT CASE 
			WHEN 
				EXISTS (
					SELECT 1 FROM flashcard_share_permit 
					WHERE fc_set_id = arg_fc_set_id AND user_id = arg_user_id
				) 
				OR 
				EXISTS (                                                                       
					SELECT 1 FROM flashcard_set
					WHERE fc_set_id = arg_fc_set_id AND (created_by = arg_user_id OR access = 'public' OR system_belong = TRUE)
				)
			THEN true ELSE false 
		END INTO isAllow;

		RETURN isAllow;
	END;
$$;


ALTER FUNCTION public.check_flashcard_permission(arg_user_id integer, arg_fc_set_id integer) OWNER TO examify_pxac_user;

--
-- Name: check_join_course(integer, integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.check_join_course(arg_user_id integer, arg_course_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		isJoin boolean;
	BEGIN		
		SELECT CASE WHEN TEM.course_id = course.course_id THEN true ELSE false END INTO isJoin
		FROM course
		LEFT JOIN (
		  SELECT course_id 
		  FROM join_course
		  WHERE student_id = arg_user_id
		) AS TEM ON course.course_id = TEM.course_id
		WHERE course.course_id = arg_course_id;

		RETURN isJoin;
	END;
$$;


ALTER FUNCTION public.check_join_course(arg_user_id integer, arg_course_id integer) OWNER TO examify_pxac_user;

--
-- Name: decrease_total_chapter(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.decrease_total_chapter() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
-- 	Trigger:
	UPDATE course SET total_chapter = (total_chapter - 1) WHERE course_id = OLD.course_id;
	
	RAISE NOTICE 'Updated total chapter in course!';
	RETURN OLD;
END;

$$;


ALTER FUNCTION public.decrease_total_chapter() OWNER TO examify_pxac_user;

--
-- Name: decrease_total_exam(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.decrease_total_exam() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	UPDATE exam_series SET total_exam = total_exam - 1 WHERE OLD.exam_series_id = exam_series_id;

	RAISE NOTICE 'Auto decrease total_exam successfully';
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.decrease_total_exam() OWNER TO examify_pxac_user;

--
-- Name: decrease_total_lesson(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.decrease_total_lesson() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
#variable_conflict use_variable
DECLARE var_unit_id INTEGER;
DECLARE var_chapter_id INTEGER;
DECLARE var_course_id INTEGER;
BEGIN
	var_unit_id := OLD.unit_id; 
	SELECT chapter_id INTO var_chapter_id FROM unit WHERE unit_id = var_unit_id;
	SELECT course_id INTO var_course_id FROM chapter WHERE chapter_id = var_chapter_id;
-- 	Trigger:
	UPDATE unit SET total_lesson = (total_lesson - 1) WHERE unit_id = var_unit_id;
	UPDATE chapter SET total_lesson = (total_lesson - 1) WHERE chapter_id = var_chapter_id;
	UPDATE course SET total_lesson = (total_lesson - 1) WHERE course_id = var_course_id;
	
	RAISE NOTICE 'Updated total lesson in unit, chapter and course!';
	RETURN NEW;
END;

$$;


ALTER FUNCTION public.decrease_total_lesson() OWNER TO examify_pxac_user;

--
-- Name: decrease_total_video_course(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.decrease_total_video_course() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
#variable_conflict use_variable
DECLARE var_type SMALLINT;
DECLARE var_video_time INTEGER;
DECLARE var_course_id INTEGER;
BEGIN
	var_type:= OLD.type;
	var_video_time:= OLD.video_time;
	--check
	IF var_type = 1 AND var_video_time != 0 THEN
		SELECT chapter.course_id INTO var_course_id
		FROM chapter, unit
		WHERE unit.unit_id = OLD.unit_id
		AND unit.chapter_id = chapter.chapter_id;
	--Trigger	
		UPDATE course 
		SET total_video_time = total_video_time - var_video_time
		WHERE  course_id = var_course_id;
	--Notice	
		RAISE NOTICE 'Updated total video time in course!';
	END IF;
	RETURN NULL;
END
$$;


ALTER FUNCTION public.decrease_total_video_course() OWNER TO examify_pxac_user;

--
-- Name: fn_check_user_like(integer, integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_check_user_like(arg_user_id integer, arg_comment_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		isExist boolean;
	BEGIN
		SELECT CASE WHEN user_id = arg_user_id AND comment_id = arg_comment_id THEN true ELSE false END INTO isExist
		FROM likes
		WHERE user_id = arg_user_id AND comment_id = arg_comment_id;
		
		RETURN isExist;
	END;
$$;


ALTER FUNCTION public.fn_check_user_like(arg_user_id integer, arg_comment_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_create_a_role_user(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_create_a_role_user() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		INSERT INTO user_to_role(user_id, role_id) VALUES(NEW.user_id, 4);
		RAISE NOTICE 'Create a new user_to_role for user!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_create_a_role_user() OWNER TO examify_pxac_user;

--
-- Name: fn_create_update_rating_course(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_create_update_rating_course() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_course_id INTEGER;
DECLARE var_quatity_rating INTEGER;
DECLARE var_avg_rating NUMERIC(3,2);
	BEGIN
		var_course_id:= NEW.course_id;
		IF EXISTS (SELECT 1 FROM rating WHERE course_id = var_course_id) THEN
			SELECT COUNT(*), AVG(rating.rate) INTO var_quatity_rating, var_avg_rating
			FROM rating
			WHERE rating.course_id = var_course_id;
		
			UPDATE course 
			SET quantity_rating = var_quatity_rating, avg_rating = var_avg_rating
			WHERE course_id = var_course_id;
		ELSE
			UPDATE course 
			SET quantity_rating = 0, avg_rating = 0
			WHERE course_id = var_course_id;
		END IF;
			RAISE NOTICE'Updated quantity rating and average rating!';
	RETURN NULL;
	END
$$;


ALTER FUNCTION public.fn_create_update_rating_course() OWNER TO examify_pxac_user;

--
-- Name: fn_decrease_total_part_exam(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_decrease_total_part_exam() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		UPDATE exam SET total_part = total_part - 1 WHERE exam_id = OLD.exam_id;
		RAISE NOTICE 'Updated total_part in exam!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_decrease_total_part_exam() OWNER TO examify_pxac_user;

--
-- Name: fn_decrease_total_question_exam(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_decrease_total_question_exam() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_exam_id INT;
	BEGIN
		SELECT part.exam_id INTO var_exam_id
		FROM set_question, part
		WHERE set_question.part_id = part.part_id
		AND set_question.set_question_id = OLD.set_question_id;
-- 		decrement total_question
		UPDATE exam SET total_question = total_question - 1 WHERE exam_id = var_exam_id;
		
		RAISE NOTICE 'Updated total_question in exam!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_decrease_total_question_exam() OWNER TO examify_pxac_user;

--
-- Name: fn_decrease_total_question_part(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_decrease_total_question_part() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_part_id INT;
	BEGIN
		SELECT set_question.part_id INTO var_part_id
		FROM set_question
		WHERE set_question.set_question_id = OLD.set_question_id;
-- 		decrement total_question
		UPDATE part SET total_question = total_question - 1 WHERE part_id = var_part_id;
		
		RAISE NOTICE 'Updated total_question in part!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_decrease_total_question_part() OWNER TO examify_pxac_user;

--
-- Name: fn_delete_chapter(integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_chapter(arg_chapter_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
		FOR var_recode IN 
			SELECT unit_id
			FROM unit
			WHERE chapter_id = arg_chapter_id
		 LOOP
			PERFORM fn_delete_unit(var_recode.unit_id);
		END LOOP;
		
		DELETE FROM chapter where chapter_id = arg_chapter_id;
		RAISE NOTICE 'Delete chapter success!';
	END;
$$;


ALTER FUNCTION public.fn_delete_chapter(arg_chapter_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_delete_choice(integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_choice(arg_choice_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
-- 		Delete answer_record reference:
		DELETE FROM answer_record WHERE choice_id = arg_choice_id;
-- 		Delete Choice:
		DELETE FROM choice WHERE choice_id = arg_choice_id;
 			RAISE NOTICE 'Deleted choice!';
	END;
$$;


ALTER FUNCTION public.fn_delete_choice(arg_choice_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_delete_comment(integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_comment(arg_comment_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
	BEGIN
-- 		Detete all relationship 
		DELETE FROM likes where comment_id = arg_comment_id;
-- 		Delete comment
		DELETE FROM comment where comment_id = arg_comment_id;
		
		RAISE NOTICE 'Delete comment success!';
	END;
$$;


ALTER FUNCTION public.fn_delete_comment(arg_comment_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_delete_course(integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_course(arg_course_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
-- 	Delete comment reference
		FOR var_recode IN 
			SELECT comment_id
			FROM comment
			WHERE course_id = arg_course_id
		 LOOP
			PERFORM fn_delete_comment(var_recode.comment_id);
		END LOOP;
-- 	Delete Join_course reference
		DELETE FROM join_course WHERE course_id = arg_course_id;
-- 	Delete Raing reference
		DELETE FROM rating WHERE course_id = arg_course_id;
-- 	Delete chapter reference
		FOR var_recode IN 
			SELECT chapter_id
			FROM chapter
			WHERE course_id = arg_course_id
		 LOOP
			PERFORM fn_delete_chapter(var_recode.chapter_id);
		END LOOP;
		
		DELETE FROM course WHERE course_id = arg_course_id;
		RAISE NOTICE 'Delete course success!';
	END;
$$;


ALTER FUNCTION public.fn_delete_course(arg_course_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_delete_exam(integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_exam(arg_exam_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
-- 		Delete part reference:
		FOR var_recode IN 
			SELECT part_id
			FROM part
			WHERE part.exam_id = arg_exam_id
		 LOOP
			PERFORM fn_delete_part(var_recode.part_id);
		END LOOP;
-- 		Delete exam taking reference:
		DELETE FROM exam_taking WHERE exam_id = arg_exam_id;

-- 		Delete exam:
		DELETE FROM exam WHERE exam_id = arg_exam_id;
		RAISE NOTICE 'Deleted exam!';
	END;
$$;


ALTER FUNCTION public.fn_delete_exam(arg_exam_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_delete_exam_series(integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_exam_series(arg_exam_series_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
-- 		Delete exam reference:
		FOR var_recode IN 
			SELECT exam_id
			FROM exam
			WHERE exam.exam_series_id = arg_exam_series_id
		 LOOP
			PERFORM fn_delete_exam(var_recode.exam_id);
		END LOOP;

-- 		Delete exam series:
		DELETE FROM exam_series WHERE exam_series_id = arg_exam_series_id;
		RAISE NOTICE 'Deleted exam series!';
	END;
$$;


ALTER FUNCTION public.fn_delete_exam_series(arg_exam_series_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_delete_lesson(integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_lesson(arg_lesson_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
	BEGIN
		-- Delete all relationship
		DELETE FROM note WHERE lesson_id = arg_lesson_id;
		DELETE FROM slide WHERE lesson_id = arg_lesson_id;
		DELETE FROM join_lesson WHERE lesson_id = arg_lesson_id;
		-- Delete lesson
		DELETE FROM lesson where lesson_id = arg_lesson_id;
		RAISE NOTICE 'Deleted lesson success!';
	END;
$$;


ALTER FUNCTION public.fn_delete_lesson(arg_lesson_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_delete_part(integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_part(arg_part_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
-- 		Delete set question reference:
		FOR var_recode IN 
			SELECT set_question_id
			FROM set_question
			WHERE set_question.part_id = arg_part_id
		 LOOP
			PERFORM fn_delete_set_question(var_recode.set_question_id);
		END LOOP;
-- 		Delete part option reference:
		DELETE FROM part_option WHERE part_id = arg_part_id;

-- 		Delete part:
		DELETE FROM part WHERE part_id = arg_part_id;
		RAISE NOTICE 'Deleted part!';
	END;
$$;


ALTER FUNCTION public.fn_delete_part(arg_part_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_delete_question(integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_question(arg_question_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
-- 		Delete choice reference:
		FOR var_recode IN 
			SELECT choice_id
			FROM choice
			WHERE choice.question_id = arg_question_id
		 LOOP
			PERFORM fn_delete_choice(var_recode.choice_id);
		END LOOP;
-- 		Delete question:
		DELETE FROM question WHERE question_id = arg_question_id;
		RAISE NOTICE 'Deleted question!';
	END;
$$;


ALTER FUNCTION public.fn_delete_question(arg_question_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_delete_rating_course(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_rating_course() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_course_id INTEGER;
DECLARE var_quatity_rating INTEGER;
DECLARE var_avg_rating NUMERIC(3,2);
	BEGIN
		var_course_id:= OLD.course_id;
		IF EXISTS (SELECT 1 FROM rating WHERE course_id = var_course_id) THEN
			SELECT COUNT(*), AVG(rating.rate) INTO var_quatity_rating, var_avg_rating
			FROM rating
			WHERE rating.course_id = var_course_id;
		
			UPDATE course 
			SET quantity_rating = var_quatity_rating, avg_rating = var_avg_rating
			WHERE course_id = var_course_id;
		ELSE
			UPDATE course 
			SET quantity_rating = 0, avg_rating = 0
			WHERE course_id = var_course_id;
		END IF;
			RAISE NOTICE'Updated quantity rating and average rating!';
	RETURN NULL;
	END
$$;


ALTER FUNCTION public.fn_delete_rating_course() OWNER TO examify_pxac_user;

--
-- Name: fn_delete_set_question(integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_set_question(arg_set_question_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode_question RECORD;
DECLARE var_recode_side RECORD;
	BEGIN
-- 		Delete question reference:
		FOR var_recode_question IN 
			SELECT question_id
			FROM question
			WHERE question.set_question_id = arg_set_question_id
		 LOOP
			PERFORM fn_delete_question(var_recode_question.question_id);
		END LOOP;
-- 		Delete side reference:
		DELETE FROM side WHERE set_question_id = arg_set_question_id;

-- 		Delete set question:
		DELETE FROM set_question WHERE set_question_id = arg_set_question_id;
		RAISE NOTICE 'Deleted set question!';
	END;
$$;


ALTER FUNCTION public.fn_delete_set_question(arg_set_question_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_delete_unit(integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_delete_unit(arg_unit_id integer) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
		FOR var_recode IN 
			SELECT lesson_id
			FROM lesson
			WHERE unit_id = arg_unit_id
		 LOOP
			PERFORM fn_delete_lesson(var_recode.lesson_id);
		END LOOP;
		
		DELETE FROM unit where unit_id = arg_unit_id;
		RAISE NOTICE 'Delete unit success!';
	END;
$$;


ALTER FUNCTION public.fn_delete_unit(arg_unit_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_enroll_course(integer, integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_enroll_course(arg_user_id integer, arg_course_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE var_accumulated_point INTEGER;
DECLARE var_point_to_unlock INTEGER;
	BEGIN
		SELECT accumulated_point 
		INTO var_accumulated_point
		FROM users WHERE user_id = arg_user_id;
		
		SELECT point_to_unlock 
		INTO var_point_to_unlock
		FROM course WHERE course_id = arg_course_id;
		
		IF var_accumulated_point >= var_point_to_unlock THEN
			INSERT INTO join_course 
			VALUES(arg_user_id, arg_course_id);
			
			UPDATE users SET accumulated_point = accumulated_point - var_point_to_unlock
			WHERE user_id = arg_user_id;
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END IF;	
	END;
$$;


ALTER FUNCTION public.fn_enroll_course(arg_user_id integer, arg_course_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_enroll_course_charges(integer, integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_enroll_course_charges(arg_user_id integer, arg_course_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE var_charges Boolean;
	BEGIN
	SELECT charges INTO var_charges FROM course WHERE course_id = arg_course_id;
-- 	Check course charges
		IF var_charges = TRUE THEN
			INSERT INTO join_course VALUES(arg_user_id, arg_course_id);
			RETURN TRUE;
		ELSE
			RETURN FALSE;
		END IF;	
	END;
$$;


ALTER FUNCTION public.fn_enroll_course_charges(arg_user_id integer, arg_course_id integer) OWNER TO examify_pxac_user;

--
-- Name: fn_increase_nums_join_exam(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_increase_nums_join_exam() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		UPDATE exam 
		SET nums_join = nums_join + 1
		WHERE exam_id = NEW.exam_id;
		
		RAISE NOTICE'Updated nums_join in exam!';
	RETURN NEW;
	END
$$;


ALTER FUNCTION public.fn_increase_nums_join_exam() OWNER TO examify_pxac_user;

--
-- Name: fn_increase_participants_course(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_increase_participants_course() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		UPDATE course 
		SET participants = participants + 1
		WHERE course_id = NEW.course_id;
		
		RAISE NOTICE'Updated participants in course!';
	RETURN NEW;
	END
$$;


ALTER FUNCTION public.fn_increase_participants_course() OWNER TO examify_pxac_user;

--
-- Name: fn_increase_total_part_exam(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_increase_total_part_exam() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	BEGIN
		UPDATE exam SET total_part = total_part + 1 WHERE exam_id = NEW.exam_id;
		RAISE NOTICE 'Updated total_part in exam!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_increase_total_part_exam() OWNER TO examify_pxac_user;

--
-- Name: fn_increase_total_question_exam(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_increase_total_question_exam() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_exam_id INT;
	BEGIN
		SELECT part.exam_id INTO var_exam_id
		FROM set_question, part
		WHERE set_question.part_id = part.part_id
		AND set_question.set_question_id = NEW.set_question_id;
-- 		increment total_question
		UPDATE exam SET total_question = total_question + 1 WHERE exam_id = var_exam_id;
		
		RAISE NOTICE 'Updated total_question in exam!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_increase_total_question_exam() OWNER TO examify_pxac_user;

--
-- Name: fn_increase_total_question_part(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_increase_total_question_part() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_part_id INT;
	BEGIN
		SELECT set_question.part_id INTO var_part_id
		FROM set_question
		WHERE set_question.set_question_id = NEW.set_question_id;
-- 		increment total_question
		UPDATE part SET total_question = total_question + 1 WHERE part_id = var_part_id;
		
		RAISE NOTICE 'Updated total_question in part!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_increase_total_question_part() OWNER TO examify_pxac_user;

--
-- Name: fn_monday_nearly(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_monday_nearly() RETURNS timestamp without time zone
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		var_monday timestamp;
		var_distance integer;
	BEGIN
		SELECT extract(isodow from NOW()) INTO var_distance;
		var_monday:= NOW()::date - (var_distance - 1) * INTERVAL '1 day' ;
		
		RETURN var_monday;
	END;
$$;


ALTER FUNCTION public.fn_monday_nearly() OWNER TO examify_pxac_user;

--
-- Name: fn_num_order_part_delete(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_num_order_part_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
		FOR var_recode IN 
			SELECT part_id
			FROM part 
			WHERE exam_id = OLD.exam_id
			AND numeric_order > OLD.numeric_order
			ORDER BY numeric_order ASC
		 LOOP
		 	UPDATE part SET numeric_order = numeric_order - 1 WHERE part_id = var_recode.part_id;
		END LOOP;
		RAISE NOTICE 'Updated numeric_order in Part!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_num_order_part_delete() OWNER TO examify_pxac_user;

--
-- Name: fn_num_order_part_update(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_num_order_part_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_new_num int;
DECLARE var_old_num int;
DECLARE var_old_part_id int;
DECLARE var_old_exam_id int;
DECLARE var_record RECORD;
	BEGIN
		var_new_num := NEW.numeric_order;
		var_old_num := OLD.numeric_order;
		var_old_part_id := OLD.part_id;
		var_old_exam_id := OLD.exam_id;
		
		IF EXISTS(SELECT * FROM part WHERE numeric_order = var_new_num AND exam_id = var_old_exam_id) THEN
-- 			Create temp Exam:
			INSERT INTO exam(exam_id, name) VALUES(-1, '');
-- 			Handle new_num > old_num:
			IF var_new_num > var_old_num THEN 
				UPDATE part SET exam_id = -1 WHERE part_id = var_old_part_id;
				
				FOR var_record IN 
					SELECT part_id 
					FROM part
					WHERE exam_id = var_old_exam_id
					AND numeric_order > var_old_num 
					AND numeric_order <= var_new_num
					ORDER BY numeric_order ASC
				LOOP
					UPDATE part SET numeric_order = numeric_order - 1 WHERE part_id = var_record.part_id;
				END LOOP;
			ELSE 
-- 				Handle new_num < old_num:
				IF var_new_num < var_old_num THEN 
					UPDATE part SET exam_id = -1 WHERE part_id = var_old_part_id;
					
					FOR var_record IN 
						SELECT part_id 
						FROM part
						WHERE exam_id = var_old_exam_id
						AND numeric_order < var_old_num 
						AND numeric_order >= var_new_num
						ORDER BY numeric_order DESC
					LOOP
						UPDATE part SET numeric_order = numeric_order + 1 WHERE part_id = var_record.part_id;
					END LOOP;
				END IF;
			END IF;
-- 			Update:
			UPDATE part SET numeric_order = var_new_num, exam_id = var_old_exam_id WHERE part_id = var_old_part_id;
-- 			Delete temp Exam:
			DELETE FROM exam WHERE exam_id = -1;
		END IF;
		RAISE NOTICE 'updated numeric order of part successfull!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_num_order_part_update() OWNER TO examify_pxac_user;

--
-- Name: fn_num_order_question_delete(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_num_order_question_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
		FOR var_recode IN 
			SELECT question_id
			FROM question 
			WHERE set_question_id = OLD.set_question_id
			AND order_qn > OLD.order_qn
			ORDER BY order_qn ASC
		 LOOP
		 	UPDATE question SET order_qn = order_qn - 1 WHERE question_id = var_recode.question_id;
		END LOOP;
		RAISE NOTICE 'Updated numeric_order in Question!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_num_order_question_delete() OWNER TO examify_pxac_user;

--
-- Name: fn_num_order_question_update(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_num_order_question_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_new_num int;
DECLARE var_old_num int;
DECLARE var_old_question_id int;
DECLARE var_old_set_question_id int;
DECLARE var_record RECORD;
	BEGIN
		var_new_num := NEW.order_qn;
		var_old_num := OLD.order_qn;
		var_old_question_id := OLD.question_id;
		var_old_set_question_id := OLD.set_question_id;
		
		IF EXISTS(SELECT * FROM question WHERE order_qn = var_new_num AND set_question_id = var_old_set_question_id) THEN
-- 			Create temp set question:
			INSERT INTO set_question(set_question_id, title, numeric_order) VALUES(-1, '', 0);
-- 			Handle new_num > old_num:
			IF var_new_num > var_old_num THEN 
				UPDATE question SET set_question_id = -1 WHERE question_id = var_old_question_id;
				
				FOR var_record IN 
					SELECT question_id 
					FROM question
					WHERE set_question_id = var_old_set_question_id
					AND order_qn > var_old_num 
					AND order_qn <= var_new_num
					ORDER BY order_qn ASC
				LOOP
					UPDATE question SET order_qn = order_qn - 1 WHERE question_id = var_record.question_id;
				END LOOP;
			ELSE 
-- 				Handle new_num < old_num:
				IF var_new_num < var_old_num THEN 
					UPDATE question SET set_question_id = -1 WHERE question_id = var_old_question_id;
					
					FOR var_record IN 
						SELECT question_id 
						FROM question
						WHERE set_question_id = var_old_set_question_id
						AND order_qn < var_old_num 
						AND order_qn >= var_new_num
						ORDER BY order_qn DESC
					LOOP
						UPDATE question SET order_qn = order_qn + 1 WHERE question_id = var_record.question_id;
					END LOOP;
				END IF;
			END IF;
-- 			Update:
			UPDATE question SET order_qn = var_new_num, set_question_id = var_old_set_question_id WHERE question_id = var_old_question_id;
-- 			Delete temp set question:
			DELETE FROM set_question WHERE set_question_id = -1;
		END IF;
		RAISE NOTICE 'updated numeric order of question successfull!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_num_order_question_update() OWNER TO examify_pxac_user;

--
-- Name: fn_num_order_set_question_delete(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_num_order_set_question_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
		FOR var_recode IN 
			SELECT set_question_id
			FROM set_question 
			WHERE part_id = OLD.part_id
			AND numeric_order > OLD.numeric_order
			ORDER BY numeric_order ASC
		 LOOP
		 	UPDATE set_question SET numeric_order = numeric_order - 1 WHERE set_question_id = var_recode.set_question_id;
		END LOOP;
		RAISE NOTICE 'Updated numeric_order in Set Question!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_num_order_set_question_delete() OWNER TO examify_pxac_user;

--
-- Name: fn_num_order_set_question_update(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_num_order_set_question_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_new_num int;
DECLARE var_old_num int;
DECLARE var_old_set_question_id int;
DECLARE var_old_part_id int;
DECLARE var_record RECORD;
	BEGIN
		var_new_num := NEW.numeric_order;
		var_old_num := OLD.numeric_order;
		var_old_set_question_id := OLD.set_question_id;
		var_old_part_id := OLD.part_id;
		
		IF EXISTS(SELECT * FROM set_question WHERE numeric_order = var_new_num AND part_id = var_old_part_id) THEN
-- 			Create temp Part:
			INSERT INTO part(part_id, name, numeric_order) VALUES(-1, '', 0);
-- 			Handle new_num > old_num:
			IF var_new_num > var_old_num THEN 
				UPDATE set_question SET part_id = -1 WHERE set_question_id = var_old_set_question_id;
				
				FOR var_record IN 
					SELECT set_question_id 
					FROM set_question
					WHERE part_id = var_old_part_id
					AND numeric_order > var_old_num 
					AND numeric_order <= var_new_num
					ORDER BY numeric_order ASC
				LOOP
					UPDATE set_question SET numeric_order = numeric_order - 1 WHERE set_question_id = var_record.set_question_id;
				END LOOP;
			ELSE 
-- 				Handle new_num < old_num:
				IF var_new_num < var_old_num THEN 
					UPDATE set_question SET part_id = -1 WHERE set_question_id = var_old_set_question_id;
					
					FOR var_record IN 
						SELECT set_question_id 
						FROM set_question
						WHERE part_id = var_old_part_id
						AND numeric_order < var_old_num 
						AND numeric_order >= var_new_num
						ORDER BY numeric_order DESC
					LOOP
						UPDATE set_question SET numeric_order = numeric_order + 1 WHERE set_question_id = var_record.set_question_id;
					END LOOP;
				END IF;
			END IF;
-- 			Update:
			UPDATE set_question SET numeric_order = var_new_num, part_id = var_old_part_id WHERE set_question_id = var_old_set_question_id;
-- 			Delete temp Part:
			DELETE FROM part WHERE part_id = -1;
		END IF;
		RAISE NOTICE 'updated numeric order of set question successfull!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_num_order_set_question_update() OWNER TO examify_pxac_user;

--
-- Name: fn_num_order_side_delete(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_num_order_side_delete() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
		FOR var_recode IN 
			SELECT side_id
			FROM side 
			WHERE set_question_id = OLD.set_question_id
			AND seq > OLD.seq
			ORDER BY seq ASC
		 LOOP
		 	UPDATE side SET seq = seq - 1 WHERE side_id = var_recode.side_id;
		END LOOP;
		RAISE NOTICE 'Updated numeric_order in Side!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_num_order_side_delete() OWNER TO examify_pxac_user;

--
-- Name: fn_num_order_side_update(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_num_order_side_update() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_new_num int;
DECLARE var_old_num int;
DECLARE var_old_side_id int;
DECLARE var_old_set_question_id int;
DECLARE var_record RECORD;
	BEGIN
		var_new_num := NEW.seq;
		var_old_num := OLD.seq;
		var_old_side_id := OLD.side_id;
		var_old_set_question_id := OLD.set_question_id;
		
		IF EXISTS(SELECT * FROM side WHERE seq = var_new_num AND set_question_id = var_old_set_question_id) THEN
-- 			Create temp set question:
			INSERT INTO set_question(set_question_id, title, numeric_order) VALUES(-1, '', 0);
-- 			Handle new_num > old_num:
			IF var_new_num > var_old_num THEN 
				UPDATE side SET set_question_id = -1 WHERE side_id = var_old_side_id;
				
				FOR var_record IN 
					SELECT side_id 
					FROM side
					WHERE set_question_id = var_old_set_question_id
					AND seq > var_old_num 
					AND seq <= var_new_num
					ORDER BY seq ASC
				LOOP
					UPDATE side SET seq = seq - 1 WHERE side_id = var_record.side_id;
				END LOOP;
			ELSE 
-- 				Handle new_num < old_num:
				IF var_new_num < var_old_num THEN 
					UPDATE side SET set_question_id = -1 WHERE side_id = var_old_side_id;
					
					FOR var_record IN 
						SELECT side_id 
						FROM side
						WHERE set_question_id = var_old_set_question_id
						AND seq < var_old_num 
						AND seq >= var_new_num
						ORDER BY seq DESC
					LOOP
						UPDATE side SET seq = seq + 1 WHERE side_id = var_record.side_id;
					END LOOP;
				END IF;
			END IF;
-- 			Update:
			UPDATE side SET seq = var_new_num, set_question_id = var_old_set_question_id WHERE side_id = var_old_side_id;
-- 			Delete temp set question:
			DELETE FROM set_question WHERE set_question_id = -1;
		END IF;
		RAISE NOTICE 'updated numeric order of side successfull!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_num_order_side_update() OWNER TO examify_pxac_user;

--
-- Name: fn_update_numeric_order_chapter(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_update_numeric_order_chapter() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
		FOR var_recode IN 
			SELECT chapter_id
			FROM chapter
			WHERE course_id = OLD.course_id
			AND numeric_order > OLD.numeric_order
			ORDER BY numeric_order ASC
		 LOOP
		 	UPDATE chapter SET numeric_order = numeric_order - 1 WHERE chapter_id = var_recode.chapter_id;
		END LOOP;
		RAISE NOTICE 'Updated numeric_order in chapter!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_update_numeric_order_chapter() OWNER TO examify_pxac_user;

--
-- Name: fn_update_numeric_order_lesson(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_update_numeric_order_lesson() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
		FOR var_recode IN 
			SELECT lesson_id
			FROM lesson
			WHERE unit_id = OLD.unit_id
			AND numeric_order > OLD.numeric_order
			ORDER BY numeric_order ASC
		 LOOP
		 	UPDATE lesson SET numeric_order = numeric_order - 1 WHERE lesson_id = var_recode.lesson_id;
		END LOOP;
		RAISE NOTICE 'Updated numeric_order in lesson!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_update_numeric_order_lesson() OWNER TO examify_pxac_user;

--
-- Name: fn_update_numeric_order_unit(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.fn_update_numeric_order_unit() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE var_recode RECORD;
	BEGIN
		FOR var_recode IN 
			SELECT unit_id
			FROM unit
			WHERE chapter_id = OLD.chapter_id
			AND numeric_order > OLD.numeric_order
			ORDER BY numeric_order ASC
		 LOOP
		 	UPDATE unit SET numeric_order = numeric_order - 1 WHERE unit_id = var_recode.unit_id;
		END LOOP;
		RAISE NOTICE 'Updated numeric_order in unit!';
	RETURN NULL;
	END;
$$;


ALTER FUNCTION public.fn_update_numeric_order_unit() OWNER TO examify_pxac_user;

--
-- Name: get_status_learned_chapter(integer, integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.get_status_learned_chapter(arg_user_id integer, arg_chapter_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		status int;
	BEGIN		
		SELECT CASE WHEN total = learned THEN 2 ELSE 1 END INTO status
		FROM (
			SELECT chapter.total_lesson AS total, COUNT(*) AS learned
			FROM chapter, unit
			INNER JOIN lesson ON unit.unit_id = lesson.unit_id
			INNER JOIN join_lesson ON lesson.lesson_id = join_lesson.lesson_id
			WHERE chapter.chapter_id = arg_chapter_id
			AND unit.chapter_id = chapter.chapter_id
			AND join_lesson.student_id = arg_user_id
			GROUP BY chapter.chapter_id
		) AS TEM;

		RETURN status;
	END;
$$;


ALTER FUNCTION public.get_status_learned_chapter(arg_user_id integer, arg_chapter_id integer) OWNER TO examify_pxac_user;

--
-- Name: get_status_learned_unit(integer, integer); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.get_status_learned_unit(arg_user_id integer, arg_unit_id integer) RETURNS integer
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		status int;
	BEGIN		
		SELECT CASE WHEN total = learned THEN 2 ELSE 1 END INTO status
		FROM (
		  SELECT unit.total_lesson AS total, COUNT(*) AS learned
		  FROM unit, lesson
		  INNER JOIN join_lesson ON lesson.lesson_id = join_lesson.lesson_id
		  WHERE unit.unit_id = arg_unit_id
		  AND unit.unit_id = lesson.unit_id
		  AND join_lesson.student_id = arg_user_id
		  GROUP BY unit.unit_id
		) AS TEM;

		RETURN status;
	END;
$$;


ALTER FUNCTION public.get_status_learned_unit(arg_user_id integer, arg_unit_id integer) OWNER TO examify_pxac_user;

--
-- Name: increase_one_participant_course(integer); Type: PROCEDURE; Schema: public; Owner: examify_pxac_user
--

CREATE PROCEDURE public.increase_one_participant_course(IN course_id_increase integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
   UPDATE course SET participants = participants + 1 WHERE course_id = course_id_increase;
END;
$$;


ALTER PROCEDURE public.increase_one_participant_course(IN course_id_increase integer) OWNER TO examify_pxac_user;

--
-- Name: increase_total_chapter(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.increase_total_chapter() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
-- 	Trigger:
	UPDATE course SET total_chapter = (total_chapter + 1) WHERE course_id = NEW.course_id;
	
	RAISE NOTICE 'Updated total chapter in course!';
	RETURN NEW;
END;

$$;


ALTER FUNCTION public.increase_total_chapter() OWNER TO examify_pxac_user;

--
-- Name: increase_total_exam(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.increase_total_exam() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
	UPDATE exam_series SET total_exam = total_exam + 1 WHERE NEW.exam_series_id = exam_series_id;

	RAISE NOTICE 'Auto increase total_exam successfully';
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.increase_total_exam() OWNER TO examify_pxac_user;

--
-- Name: increase_total_lesson(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.increase_total_lesson() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
#variable_conflict use_variable
DECLARE var_unit_id INTEGER;
DECLARE var_chapter_id INTEGER;
DECLARE var_course_id INTEGER;
BEGIN
	var_unit_id := NEW.unit_id;
	SELECT chapter_id INTO var_chapter_id FROM unit WHERE unit_id = var_unit_id;
	SELECT course_id INTO var_course_id FROM chapter WHERE chapter_id = var_chapter_id;
-- 	Trigger:
	UPDATE unit SET total_lesson = (total_lesson + 1) WHERE unit_id = var_unit_id;
	UPDATE chapter SET total_lesson = (total_lesson + 1) WHERE chapter_id = var_chapter_id;
	UPDATE course SET total_lesson = (total_lesson + 1) WHERE course_id = var_course_id;
	
	RAISE NOTICE 'Updated total lesson in unit, chapter and course!';
	RETURN NEW;
END;

$$;


ALTER FUNCTION public.increase_total_lesson() OWNER TO examify_pxac_user;

--
-- Name: increase_total_video_course(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.increase_total_video_course() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
#variable_conflict use_variable
DECLARE var_type SMALLINT;
DECLARE var_video_time INTEGER;
DECLARE var_course_id INTEGER;
BEGIN
	var_type:= NEW.type;
	var_video_time:= NEW.video_time;
	--check
	IF var_type = 1 AND var_video_time != 0 THEN
		SELECT chapter.course_id INTO var_course_id
		FROM chapter, unit
		WHERE unit.unit_id = NEW.unit_id
		AND unit.chapter_id = chapter.chapter_id;
	--Trigger	
		UPDATE course 
		SET total_video_time = total_video_time + var_video_time
		WHERE  course_id = var_course_id;
	--Notice	
		RAISE NOTICE 'Updated total video time in course!';
	END IF;
	RETURN NULL;
END
$$;


ALTER FUNCTION public.increase_total_video_course() OWNER TO examify_pxac_user;

--
-- Name: proc_like_comment(integer, integer); Type: PROCEDURE; Schema: public; Owner: examify_pxac_user
--

CREATE PROCEDURE public.proc_like_comment(IN arg_user_id integer, IN arg_comment_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
   INSERT INTO likes (user_id, comment_id) VALUES (arg_user_id, arg_comment_id);
   UPDATE comment SET total_like = total_like + 1 WHERE comment.comment_id = arg_comment_id;
END;
$$;


ALTER PROCEDURE public.proc_like_comment(IN arg_user_id integer, IN arg_comment_id integer) OWNER TO examify_pxac_user;

--
-- Name: proc_unlike_comment(integer, integer); Type: PROCEDURE; Schema: public; Owner: examify_pxac_user
--

CREATE PROCEDURE public.proc_unlike_comment(IN arg_user_id integer, IN arg_comment_id integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
   DELETE FROM likes WHERE user_id = arg_user_id AND comment_id = arg_comment_id;
   UPDATE comment SET total_like = total_like - 1 WHERE comment.comment_id = arg_comment_id;
END;
$$;


ALTER PROCEDURE public.proc_unlike_comment(IN arg_user_id integer, IN arg_comment_id integer) OWNER TO examify_pxac_user;

--
-- Name: update_reviews_stat(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.update_reviews_stat() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    p_id           INTEGER;
    avg_rating_var FLOAT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT NEW.product_id INTO p_id;

        UPDATE api_product
        SET reviews_count = reviews_count + 1
        WHERE id = p_id;
    ELSIF TG_OP = 'DELETE' THEN
        SELECT OLD.product_id INTO p_id;

        UPDATE api_product
        SET reviews_count = reviews_count - 1
        WHERE id = p_id;
    END IF;

    SELECT AVG(rating) INTO avg_rating_var FROM api_review WHERE product_id = p_id;
    RAISE NOTICE 'Update rating for product with avg_rating = %, p_id = %', avg_rating_var, p_id;
    UPDATE api_product
    SET avg_rating = avg_rating_var
    WHERE id = p_id;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_reviews_stat() OWNER TO examify_pxac_user;

--
-- Name: update_sets_count(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.update_sets_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	DECLARE update_count INT; type_id INT;
	BEGIN
		IF TG_OP = 'INSERT' THEN	
			type_id = NEW.fc_type_id;
		ELSE
			type_id = OLD.fc_type_id;
		END IF;

		update_count = (SELECT COUNT(*) FROM flashcard_set fs WHERE fs.fc_type_id = type_id);
		UPDATE flashcard_type ft SET sets_count = update_count WHERE ft.fc_type_id = type_id;
		RAISE NOTICE 'Update sets count of type: %', type_id;

		RETURN NULL;
	END;
$$;


ALTER FUNCTION public.update_sets_count() OWNER TO examify_pxac_user;

--
-- Name: update_timestamp(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.update_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
   NEW.updated_at = now(); 
   RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_timestamp() OWNER TO examify_pxac_user;

--
-- Name: update_total_lesson(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.update_total_lesson() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
#variable_conflict use_variable
DECLARE var_old_unit_id INTEGER;
DECLARE var_old_chapter_id INTEGER;
DECLARE var_old_course_id INTEGER;
DECLARE var_new_unit_id INTEGER;
DECLARE var_new_chapter_id INTEGER;
DECLARE var_new_course_id INTEGER;
BEGIN
	-- asign variable
	var_new_unit_id :=  NEW.unit_id; 
	SELECT chapter_id INTO var_new_chapter_id FROM unit WHERE unit_id = var_new_unit_id;
	SELECT course_id INTO var_new_course_id FROM chapter WHERE chapter_id = var_new_chapter_id ;
	var_old_unit_id :=  OLD.unit_id; 
	SELECT chapter_id INTO var_old_chapter_id FROM unit WHERE unit_id = var_old_unit_id;
	SELECT course_id INTO var_old_course_id FROM chapter WHERE chapter_id = var_old_chapter_id;
	-- trigger
	IF var_new_unit_id != var_old_unit_id THEN
		UPDATE unit SET total_lesson = (total_lesson + 1) WHERE unit_id = var_new_unit_id;
		UPDATE unit SET total_lesson = (total_lesson - 1) WHERE unit_id = var_old_unit_id;

		IF var_new_chapter_id != var_old_chapter_id THEN
			UPDATE chapter SET total_lesson = (total_lesson + 1) WHERE chapter_id = var_new_chapter_id;
			UPDATE chapter SET total_lesson = (total_lesson - 1) WHERE chapter_id = var_old_chapter_id;

			IF var_new_course_id != var_old_course_id THEN
				UPDATE course SET total_lesson = (total_lesson + 1) WHERE course_id = var_new_course_id;
				UPDATE course SET total_lesson = (total_lesson - 1) WHERE course_id = var_old_course_id;
			END IF;
		END IF;
	END IF;
	
	RAISE NOTICE 'Updated total lesson in unit, chapter and course!';
	RETURN NEW;
END;
$$;


ALTER FUNCTION public.update_total_lesson() OWNER TO examify_pxac_user;

--
-- Name: update_total_video_course(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.update_total_video_course() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
#variable_conflict use_variable
DECLARE var_video_time_old INTEGER;
DECLARE var_video_time_new INTEGER;
DECLARE var_course_id INTEGER;
BEGIN
	var_video_time_new:= NEW.video_time;
	var_video_time_old:= OLD.video_time;
	SELECT chapter.course_id INTO var_course_id
		FROM chapter, unit
		WHERE unit.unit_id = OLD.unit_id
		AND unit.chapter_id = chapter.chapter_id;
	--Trigger	
		UPDATE course 
		SET total_video_time = total_video_time - var_video_time_old + var_video_time_new
		WHERE  course_id = var_course_id;
	--Notice	
	RAISE NOTICE 'Updated total video time in course!';
		
	RETURN NEW;
END
$$;


ALTER FUNCTION public.update_total_video_course() OWNER TO examify_pxac_user;

--
-- Name: update_variations_count(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.update_variations_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    p_id                 INTEGER;
    variations_count_var INTEGER;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT NEW.product_id INTO p_id;
    ELSIF TG_OP = 'DELETE' THEN
        SELECT OLD.product_id INTO p_id;
    END IF;

    SELECT COUNT(*) INTO variations_count_var FROM api_variation WHERE product_id = p_id AND is_deleted = false;
    UPDATE api_product
    SET variations_count = variations_count_var
    WHERE id = p_id;
    RAISE NOTICE 'Update variations count for product with id = %', p_id;

    RETURN NULL;
END;
$$;


ALTER FUNCTION public.update_variations_count() OWNER TO examify_pxac_user;

--
-- Name: update_words_count(); Type: FUNCTION; Schema: public; Owner: examify_pxac_user
--

CREATE FUNCTION public.update_words_count() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	DECLARE update_count INT; set_id INT;
	BEGIN
		IF TG_OP = 'INSERT' THEN	
			set_id = NEW.fc_set_id;
		ELSE
			set_id = OLD.fc_set_id;
		END IF;

		update_count = (SELECT COUNT(*) FROM flashcard f WHERE f.fc_set_id = set_id);
		UPDATE flashcard_set fs SET words_count = update_count WHERE fs.fc_set_id = set_id;
		RAISE NOTICE 'Value: %', set_id;

		RETURN NULL;
	END;
$$;


ALTER FUNCTION public.update_words_count() OWNER TO examify_pxac_user;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: answer_record; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.answer_record (
    exam_taking_id integer NOT NULL,
    question_id integer NOT NULL,
    choice_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.answer_record OWNER TO examify_pxac_user;

--
-- Name: api_address; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_address (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    email character varying(254) NOT NULL,
    phone character varying(15) NOT NULL,
    full_name character varying(300) NOT NULL,
    province character varying(100) NOT NULL,
    province_code integer NOT NULL,
    district character varying(100) NOT NULL,
    district_code integer NOT NULL,
    ward character varying(100) NOT NULL,
    ward_code integer NOT NULL,
    street character varying(300) NOT NULL,
    created_by_id bigint NOT NULL
);


ALTER TABLE public.api_address OWNER TO examify_pxac_user;

--
-- Name: api_address_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_address ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_address_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_cartitem; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_cartitem (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    qty integer NOT NULL,
    created_by_id bigint NOT NULL,
    product_id bigint NOT NULL,
    variation_id bigint NOT NULL
);


ALTER TABLE public.api_cartitem OWNER TO examify_pxac_user;

--
-- Name: api_cartitem_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_cartitem ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_cartitem_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_category; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_category (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    name character varying(300) NOT NULL,
    "desc" text,
    img_url text NOT NULL,
    is_deleted boolean NOT NULL
);


ALTER TABLE public.api_category OWNER TO examify_pxac_user;

--
-- Name: api_category_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_category ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_category_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_favoriteitem; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_favoriteitem (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    created_by_id bigint NOT NULL,
    product_id bigint NOT NULL
);


ALTER TABLE public.api_favoriteitem OWNER TO examify_pxac_user;

--
-- Name: api_favoriteitem_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_favoriteitem ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_favoriteitem_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_order; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_order (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    phone character varying(15) NOT NULL,
    full_name character varying(300) NOT NULL,
    province character varying(100) NOT NULL,
    province_code integer NOT NULL,
    district character varying(100) NOT NULL,
    district_code integer NOT NULL,
    ward character varying(100) NOT NULL,
    ward_code integer NOT NULL,
    street character varying(300) NOT NULL,
    status character varying(20) NOT NULL,
    total numeric(20,2) NOT NULL,
    payment text NOT NULL,
    created_by_id bigint NOT NULL,
    email character varying(254) NOT NULL,
    shipping_date timestamp with time zone,
    voucher_id bigint
);


ALTER TABLE public.api_order OWNER TO examify_pxac_user;

--
-- Name: api_order_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_order ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_order_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_orderdetail; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_orderdetail (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    price numeric(20,2) NOT NULL,
    qty integer NOT NULL,
    order_id bigint NOT NULL,
    variation_id bigint NOT NULL,
    product_id bigint NOT NULL
);


ALTER TABLE public.api_orderdetail OWNER TO examify_pxac_user;

--
-- Name: api_orderdetail_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_orderdetail ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_orderdetail_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_payment; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_payment (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    name character varying(300) NOT NULL,
    exp date,
    provider_id bigint NOT NULL,
    created_by_id bigint NOT NULL,
    number character varying(30),
    cvc character varying(4)
);


ALTER TABLE public.api_payment OWNER TO examify_pxac_user;

--
-- Name: api_payment_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_payment ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_payment_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_paymentprovider; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_paymentprovider (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    is_deleted boolean NOT NULL,
    img_url text NOT NULL,
    name text NOT NULL,
    method character varying(50) NOT NULL
);


ALTER TABLE public.api_paymentprovider OWNER TO examify_pxac_user;

--
-- Name: api_paymentprovider_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_paymentprovider ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_paymentprovider_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_product; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_product (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    name character varying(300) NOT NULL,
    "desc" text,
    price numeric(20,2) NOT NULL,
    thumbnail text NOT NULL,
    category_id bigint NOT NULL,
    reviews_count integer NOT NULL,
    is_deleted boolean NOT NULL,
    avg_rating numeric(20,1),
    variations_count integer NOT NULL,
    discount integer NOT NULL,
    material text,
    length numeric(20,2),
    height numeric(20,2),
    more_info text,
    weight numeric(20,2),
    width numeric(20,2)
);


ALTER TABLE public.api_product OWNER TO examify_pxac_user;

--
-- Name: api_product_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_product ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_product_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_review; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_review (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    content text NOT NULL,
    rating integer NOT NULL,
    created_by_id bigint NOT NULL,
    variation_id bigint NOT NULL,
    product_id bigint NOT NULL,
    img_urls text[] NOT NULL
);


ALTER TABLE public.api_review OWNER TO examify_pxac_user;

--
-- Name: api_review_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_review ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_review_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_usedvoucher; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_usedvoucher (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    user_id bigint NOT NULL,
    voucher_id bigint NOT NULL
);


ALTER TABLE public.api_usedvoucher OWNER TO examify_pxac_user;

--
-- Name: api_usedvoucher_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_usedvoucher ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_usedvoucher_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_variation; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_variation (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    inventory integer NOT NULL,
    name character varying(300) NOT NULL,
    img_urls text[] NOT NULL,
    product_id bigint NOT NULL,
    is_deleted boolean NOT NULL
);


ALTER TABLE public.api_variation OWNER TO examify_pxac_user;

--
-- Name: api_variation_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_variation ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_variation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_voucher; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.api_voucher (
    id bigint NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    is_deleted boolean NOT NULL,
    discount integer NOT NULL,
    from_date date NOT NULL,
    to_date date NOT NULL,
    code character varying(30) NOT NULL,
    inventory integer NOT NULL
);


ALTER TABLE public.api_voucher OWNER TO examify_pxac_user;

--
-- Name: api_voucher_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.api_voucher ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_voucher_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_group; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.auth_group (
    id integer NOT NULL,
    name character varying(150) NOT NULL
);


ALTER TABLE public.auth_group OWNER TO examify_pxac_user;

--
-- Name: auth_group_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.auth_group ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_group_permissions; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.auth_group_permissions (
    id bigint NOT NULL,
    group_id integer NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.auth_group_permissions OWNER TO examify_pxac_user;

--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.auth_group_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_group_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: auth_permission; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.auth_permission (
    id integer NOT NULL,
    name character varying(255) NOT NULL,
    content_type_id integer NOT NULL,
    codename character varying(100) NOT NULL
);


ALTER TABLE public.auth_permission OWNER TO examify_pxac_user;

--
-- Name: auth_permission_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.auth_permission ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.auth_permission_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: authentication_user; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.authentication_user (
    id bigint NOT NULL,
    password character varying(128) NOT NULL,
    last_login timestamp with time zone,
    is_superuser boolean NOT NULL,
    created_at timestamp with time zone NOT NULL,
    updated_at timestamp with time zone NOT NULL,
    email character varying(254) NOT NULL,
    is_staff boolean NOT NULL,
    is_active boolean NOT NULL,
    date_joined timestamp with time zone NOT NULL,
    email_verified boolean NOT NULL,
    dob date,
    full_name text,
    gender character varying(15),
    phone character varying(15),
    avatar text NOT NULL
);


ALTER TABLE public.authentication_user OWNER TO examify_pxac_user;

--
-- Name: authentication_user_groups; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.authentication_user_groups (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    group_id integer NOT NULL
);


ALTER TABLE public.authentication_user_groups OWNER TO examify_pxac_user;

--
-- Name: authentication_user_groups_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.authentication_user_groups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.authentication_user_groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: authentication_user_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.authentication_user ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.authentication_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: authentication_user_user_permissions; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.authentication_user_user_permissions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.authentication_user_user_permissions OWNER TO examify_pxac_user;

--
-- Name: authentication_user_user_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.authentication_user_user_permissions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.authentication_user_user_permissions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: chapter; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.chapter (
    chapter_id integer NOT NULL,
    course_id integer NOT NULL,
    numeric_order integer NOT NULL,
    name character varying(150) NOT NULL,
    total_lesson smallint DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.chapter OWNER TO examify_pxac_user;

--
-- Name: chapter_chapter_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.chapter_chapter_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.chapter_chapter_id_seq OWNER TO examify_pxac_user;

--
-- Name: chapter_chapter_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.chapter_chapter_id_seq OWNED BY public.chapter.chapter_id;


--
-- Name: choice; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.choice (
    choice_id integer NOT NULL,
    question_id integer,
    order_choice integer NOT NULL,
    name text DEFAULT ''::text NOT NULL,
    key boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.choice OWNER TO examify_pxac_user;

--
-- Name: choice_choice_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.choice_choice_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.choice_choice_id_seq OWNER TO examify_pxac_user;

--
-- Name: choice_choice_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.choice_choice_id_seq OWNED BY public.choice.choice_id;


--
-- Name: comment; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.comment (
    comment_id integer NOT NULL,
    student_id integer NOT NULL,
    course_id integer NOT NULL,
    content text,
    total_like integer DEFAULT 0,
    respond_id integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.comment OWNER TO examify_pxac_user;

--
-- Name: comment_comment_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.comment_comment_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.comment_comment_id_seq OWNER TO examify_pxac_user;

--
-- Name: comment_comment_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.comment_comment_id_seq OWNED BY public.comment.comment_id;


--
-- Name: course; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.course (
    course_id integer NOT NULL,
    name character varying(150) NOT NULL,
    image text NOT NULL,
    level character varying(10) NOT NULL,
    charges boolean NOT NULL,
    point_to_unlock integer,
    point_reward integer NOT NULL,
    quantity_rating integer DEFAULT 0 NOT NULL,
    avg_rating numeric(3,2) DEFAULT 0 NOT NULL,
    participants integer DEFAULT 0 NOT NULL,
    price integer,
    discount integer,
    total_chapter integer DEFAULT 0 NOT NULL,
    total_lesson integer DEFAULT 0 NOT NULL,
    total_video_time integer DEFAULT 0 NOT NULL,
    achieves text,
    description text,
    created_by integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.course OWNER TO examify_pxac_user;

--
-- Name: course_course_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.course_course_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.course_course_id_seq OWNER TO examify_pxac_user;

--
-- Name: course_course_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.course_course_id_seq OWNED BY public.course.course_id;


--
-- Name: django_admin_log; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.django_admin_log (
    id integer NOT NULL,
    action_time timestamp with time zone NOT NULL,
    object_id text,
    object_repr character varying(200) NOT NULL,
    action_flag smallint NOT NULL,
    change_message text NOT NULL,
    content_type_id integer,
    user_id bigint NOT NULL,
    CONSTRAINT django_admin_log_action_flag_check CHECK ((action_flag >= 0))
);


ALTER TABLE public.django_admin_log OWNER TO examify_pxac_user;

--
-- Name: django_admin_log_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.django_admin_log ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_admin_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_content_type; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.django_content_type (
    id integer NOT NULL,
    app_label character varying(100) NOT NULL,
    model character varying(100) NOT NULL
);


ALTER TABLE public.django_content_type OWNER TO examify_pxac_user;

--
-- Name: django_content_type_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.django_content_type ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_content_type_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_migrations; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.django_migrations (
    id bigint NOT NULL,
    app character varying(255) NOT NULL,
    name character varying(255) NOT NULL,
    applied timestamp with time zone NOT NULL
);


ALTER TABLE public.django_migrations OWNER TO examify_pxac_user;

--
-- Name: django_migrations_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE public.django_migrations ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.django_migrations_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: django_session; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.django_session (
    session_key character varying(40) NOT NULL,
    session_data text NOT NULL,
    expire_date timestamp with time zone NOT NULL
);


ALTER TABLE public.django_session OWNER TO examify_pxac_user;

--
-- Name: exam; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.exam (
    exam_id integer NOT NULL,
    exam_series_id integer,
    name character varying(255) NOT NULL,
    total_part integer DEFAULT 0,
    total_question integer DEFAULT 0,
    total_comment integer DEFAULT 0,
    point_reward integer DEFAULT 0,
    nums_join integer DEFAULT 0,
    hashtag text[] DEFAULT ARRAY['Listening'::text, 'Reading'::text],
    is_full_explanation boolean DEFAULT false,
    audio text,
    duration integer DEFAULT 0,
    file_download text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.exam OWNER TO examify_pxac_user;

--
-- Name: exam_exam_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.exam_exam_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.exam_exam_id_seq OWNER TO examify_pxac_user;

--
-- Name: exam_exam_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.exam_exam_id_seq OWNED BY public.exam.exam_id;


--
-- Name: exam_series; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.exam_series (
    exam_series_id integer NOT NULL,
    name text NOT NULL,
    total_exam integer DEFAULT 0 NOT NULL,
    public_date date,
    author text DEFAULT ''::text,
    created_by integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.exam_series OWNER TO examify_pxac_user;

--
-- Name: exam_series_exam_series_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.exam_series_exam_series_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.exam_series_exam_series_id_seq OWNER TO examify_pxac_user;

--
-- Name: exam_series_exam_series_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.exam_series_exam_series_id_seq OWNED BY public.exam_series.exam_series_id;


--
-- Name: exam_taking; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.exam_taking (
    exam_taking_id integer NOT NULL,
    exam_id integer NOT NULL,
    user_id integer NOT NULL,
    time_finished integer DEFAULT 0 NOT NULL,
    nums_of_correct_qn integer DEFAULT 0 NOT NULL,
    total_question integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.exam_taking OWNER TO examify_pxac_user;

--
-- Name: exam_taking_exam_taking_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.exam_taking_exam_taking_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.exam_taking_exam_taking_id_seq OWNER TO examify_pxac_user;

--
-- Name: exam_taking_exam_taking_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.exam_taking_exam_taking_id_seq OWNED BY public.exam_taking.exam_taking_id;


--
-- Name: flashcard; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.flashcard (
    fc_id integer NOT NULL,
    fc_set_id integer,
    word text NOT NULL,
    meaning text NOT NULL,
    type_of_word character varying(15) NOT NULL,
    pronounce text,
    audio text,
    example text,
    note text,
    image text,
    created_by integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.flashcard OWNER TO examify_pxac_user;

--
-- Name: flashcard_fc_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.flashcard_fc_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.flashcard_fc_id_seq OWNER TO examify_pxac_user;

--
-- Name: flashcard_fc_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.flashcard_fc_id_seq OWNED BY public.flashcard.fc_id;


--
-- Name: flashcard_set; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.flashcard_set (
    fc_set_id integer NOT NULL,
    fc_type_id integer,
    name text NOT NULL,
    description text,
    words_count integer DEFAULT 0,
    system_belong boolean DEFAULT false,
    access character varying(16),
    views integer DEFAULT 0,
    created_by integer,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.flashcard_set OWNER TO examify_pxac_user;

--
-- Name: flashcard_set_fc_set_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.flashcard_set_fc_set_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.flashcard_set_fc_set_id_seq OWNER TO examify_pxac_user;

--
-- Name: flashcard_set_fc_set_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.flashcard_set_fc_set_id_seq OWNED BY public.flashcard_set.fc_set_id;


--
-- Name: flashcard_share_permit; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.flashcard_share_permit (
    user_id integer NOT NULL,
    fc_set_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.flashcard_share_permit OWNER TO examify_pxac_user;

--
-- Name: flashcard_type; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.flashcard_type (
    fc_type_id integer NOT NULL,
    type character varying(50) NOT NULL,
    description text,
    sets_count integer DEFAULT 0,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.flashcard_type OWNER TO examify_pxac_user;

--
-- Name: flashcard_type_fc_type_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.flashcard_type_fc_type_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.flashcard_type_fc_type_id_seq OWNER TO examify_pxac_user;

--
-- Name: flashcard_type_fc_type_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.flashcard_type_fc_type_id_seq OWNED BY public.flashcard_type.fc_type_id;


--
-- Name: hashtag; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.hashtag (
    hashtag_id integer NOT NULL,
    name character varying(255) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.hashtag OWNER TO examify_pxac_user;

--
-- Name: hashtag_hashtag_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.hashtag_hashtag_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.hashtag_hashtag_id_seq OWNER TO examify_pxac_user;

--
-- Name: hashtag_hashtag_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.hashtag_hashtag_id_seq OWNED BY public.hashtag.hashtag_id;


--
-- Name: join_course; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.join_course (
    student_id integer NOT NULL,
    course_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.join_course OWNER TO examify_pxac_user;

--
-- Name: join_lesson; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.join_lesson (
    student_id integer NOT NULL,
    lesson_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.join_lesson OWNER TO examify_pxac_user;

--
-- Name: learnt_list; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.learnt_list (
    fc_id integer NOT NULL,
    user_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.learnt_list OWNER TO examify_pxac_user;

--
-- Name: lesson; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.lesson (
    lesson_id integer NOT NULL,
    unit_id integer NOT NULL,
    numeric_order integer NOT NULL,
    name text NOT NULL,
    type smallint NOT NULL,
    video_url text,
    video_time integer DEFAULT 0 NOT NULL,
    flashcard_set_id integer,
    text text,
    description text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.lesson OWNER TO examify_pxac_user;

--
-- Name: lesson_lesson_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.lesson_lesson_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lesson_lesson_id_seq OWNER TO examify_pxac_user;

--
-- Name: lesson_lesson_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.lesson_lesson_id_seq OWNED BY public.lesson.lesson_id;


--
-- Name: like; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public."like" (
    user_id integer NOT NULL,
    comment_id integer NOT NULL,
    created_at timestamp with time zone
);


ALTER TABLE public."like" OWNER TO examify_pxac_user;

--
-- Name: likes; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.likes (
    user_id integer NOT NULL,
    comment_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.likes OWNER TO examify_pxac_user;

--
-- Name: note; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.note (
    note_id integer NOT NULL,
    student_id integer NOT NULL,
    lesson_id integer NOT NULL,
    note text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.note OWNER TO examify_pxac_user;

--
-- Name: note_note_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.note_note_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.note_note_id_seq OWNER TO examify_pxac_user;

--
-- Name: note_note_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.note_note_id_seq OWNED BY public.note.note_id;


--
-- Name: part; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.part (
    part_id integer NOT NULL,
    exam_id integer,
    name character varying(255) NOT NULL,
    total_question integer DEFAULT 0,
    number_of_explanation integer DEFAULT 0,
    numeric_order integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.part OWNER TO examify_pxac_user;

--
-- Name: part_option; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.part_option (
    exam_taking_id integer NOT NULL,
    part_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.part_option OWNER TO examify_pxac_user;

--
-- Name: part_part_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.part_part_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.part_part_id_seq OWNER TO examify_pxac_user;

--
-- Name: part_part_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.part_part_id_seq OWNED BY public.part.part_id;


--
-- Name: question; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.question (
    question_id integer NOT NULL,
    set_question_id integer,
    hashtag_id integer,
    name character varying(255) DEFAULT ''::character varying,
    explain text DEFAULT ''::text,
    order_qn integer NOT NULL,
    level integer DEFAULT 1 NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.question OWNER TO examify_pxac_user;

--
-- Name: question_question_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.question_question_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.question_question_id_seq OWNER TO examify_pxac_user;

--
-- Name: question_question_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.question_question_id_seq OWNED BY public.question.question_id;


--
-- Name: rank; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.rank (
    rank_id integer NOT NULL,
    rank_name text NOT NULL,
    point_to_unlock integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.rank OWNER TO examify_pxac_user;

--
-- Name: rank_rank_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.rank_rank_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.rank_rank_id_seq OWNER TO examify_pxac_user;

--
-- Name: rank_rank_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.rank_rank_id_seq OWNED BY public.rank.rank_id;


--
-- Name: rating; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.rating (
    student_id integer NOT NULL,
    course_id integer NOT NULL,
    rate integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.rating OWNER TO examify_pxac_user;

--
-- Name: roles; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.roles (
    role_id integer NOT NULL,
    role_name character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.roles OWNER TO examify_pxac_user;

--
-- Name: roles_role_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.roles_role_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.roles_role_id_seq OWNER TO examify_pxac_user;

--
-- Name: roles_role_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.roles_role_id_seq OWNED BY public.roles.role_id;


--
-- Name: set_question; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.set_question (
    set_question_id integer NOT NULL,
    part_id integer,
    title character varying(255) DEFAULT ''::character varying,
    numeric_order integer NOT NULL,
    audio text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.set_question OWNER TO examify_pxac_user;

--
-- Name: set_question_set_question_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.set_question_set_question_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.set_question_set_question_id_seq OWNER TO examify_pxac_user;

--
-- Name: set_question_set_question_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.set_question_set_question_id_seq OWNED BY public.set_question.set_question_id;


--
-- Name: side; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.side (
    side_id integer NOT NULL,
    set_question_id integer,
    paragraph text NOT NULL,
    seq integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.side OWNER TO examify_pxac_user;

--
-- Name: side_side_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.side_side_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.side_side_id_seq OWNER TO examify_pxac_user;

--
-- Name: side_side_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.side_side_id_seq OWNED BY public.side.side_id;


--
-- Name: slide; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.slide (
    slide_id integer NOT NULL,
    sequence integer NOT NULL,
    lesson_id integer,
    text text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.slide OWNER TO examify_pxac_user;

--
-- Name: slide_slide_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.slide_slide_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.slide_slide_id_seq OWNER TO examify_pxac_user;

--
-- Name: slide_slide_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.slide_slide_id_seq OWNED BY public.slide.slide_id;


--
-- Name: unit; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.unit (
    unit_id integer NOT NULL,
    chapter_id integer NOT NULL,
    numeric_order integer NOT NULL,
    name character varying(150) NOT NULL,
    total_lesson smallint DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.unit OWNER TO examify_pxac_user;

--
-- Name: unit_unit_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.unit_unit_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.unit_unit_id_seq OWNER TO examify_pxac_user;

--
-- Name: unit_unit_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.unit_unit_id_seq OWNED BY public.unit.unit_id;


--
-- Name: user_to_role; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.user_to_role (
    user_id integer NOT NULL,
    role_id integer NOT NULL,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.user_to_role OWNER TO examify_pxac_user;

--
-- Name: users; Type: TABLE; Schema: public; Owner: examify_pxac_user
--

CREATE TABLE public.users (
    user_id integer NOT NULL,
    mail text NOT NULL,
    password text NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    date_of_birth date,
    phone_number character varying(10),
    avt text DEFAULT 'https://media.istockphoto.com/id/1223671392/vector/default-profile-picture-avatar-photo-placeholder-vector-illustration.jpg?s=170667a&w=0&k=20&c=m-F9Doa2ecNYEEjeplkFCmZBlc5tm1pl1F7cBCh9ZzM='::text,
    banner text DEFAULT 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAX8AAACECAMAAABPuNs7AAAACVBMVEWAgICLi4uUlJSuV9pqAAABI0lEQVR4nO3QMQEAAAjAILV/aGPwjAjMbZybnTjbP9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b+1cxvnHi9hBAfkOyqGAAAAAElFTkSuQmCC'::text,
    description text,
    rank_id integer DEFAULT 1,
    accumulated_point integer DEFAULT 0,
    rank_point integer DEFAULT 0,
    refresh_token text DEFAULT ''::text,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    updated_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);


ALTER TABLE public.users OWNER TO examify_pxac_user;

--
-- Name: users_user_id_seq; Type: SEQUENCE; Schema: public; Owner: examify_pxac_user
--

CREATE SEQUENCE public.users_user_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.users_user_id_seq OWNER TO examify_pxac_user;

--
-- Name: users_user_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: examify_pxac_user
--

ALTER SEQUENCE public.users_user_id_seq OWNED BY public.users.user_id;


--
-- Name: chapter chapter_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.chapter ALTER COLUMN chapter_id SET DEFAULT nextval('public.chapter_chapter_id_seq'::regclass);


--
-- Name: choice choice_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.choice ALTER COLUMN choice_id SET DEFAULT nextval('public.choice_choice_id_seq'::regclass);


--
-- Name: comment comment_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.comment ALTER COLUMN comment_id SET DEFAULT nextval('public.comment_comment_id_seq'::regclass);


--
-- Name: course course_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.course ALTER COLUMN course_id SET DEFAULT nextval('public.course_course_id_seq'::regclass);


--
-- Name: exam exam_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.exam ALTER COLUMN exam_id SET DEFAULT nextval('public.exam_exam_id_seq'::regclass);


--
-- Name: exam_series exam_series_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.exam_series ALTER COLUMN exam_series_id SET DEFAULT nextval('public.exam_series_exam_series_id_seq'::regclass);


--
-- Name: exam_taking exam_taking_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.exam_taking ALTER COLUMN exam_taking_id SET DEFAULT nextval('public.exam_taking_exam_taking_id_seq'::regclass);


--
-- Name: flashcard fc_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard ALTER COLUMN fc_id SET DEFAULT nextval('public.flashcard_fc_id_seq'::regclass);


--
-- Name: flashcard_set fc_set_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard_set ALTER COLUMN fc_set_id SET DEFAULT nextval('public.flashcard_set_fc_set_id_seq'::regclass);


--
-- Name: flashcard_type fc_type_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard_type ALTER COLUMN fc_type_id SET DEFAULT nextval('public.flashcard_type_fc_type_id_seq'::regclass);


--
-- Name: hashtag hashtag_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.hashtag ALTER COLUMN hashtag_id SET DEFAULT nextval('public.hashtag_hashtag_id_seq'::regclass);


--
-- Name: lesson lesson_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.lesson ALTER COLUMN lesson_id SET DEFAULT nextval('public.lesson_lesson_id_seq'::regclass);


--
-- Name: note note_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.note ALTER COLUMN note_id SET DEFAULT nextval('public.note_note_id_seq'::regclass);


--
-- Name: part part_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.part ALTER COLUMN part_id SET DEFAULT nextval('public.part_part_id_seq'::regclass);


--
-- Name: question question_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.question ALTER COLUMN question_id SET DEFAULT nextval('public.question_question_id_seq'::regclass);


--
-- Name: rank rank_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.rank ALTER COLUMN rank_id SET DEFAULT nextval('public.rank_rank_id_seq'::regclass);


--
-- Name: roles role_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.roles ALTER COLUMN role_id SET DEFAULT nextval('public.roles_role_id_seq'::regclass);


--
-- Name: set_question set_question_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.set_question ALTER COLUMN set_question_id SET DEFAULT nextval('public.set_question_set_question_id_seq'::regclass);


--
-- Name: side side_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.side ALTER COLUMN side_id SET DEFAULT nextval('public.side_side_id_seq'::regclass);


--
-- Name: slide slide_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.slide ALTER COLUMN slide_id SET DEFAULT nextval('public.slide_slide_id_seq'::regclass);


--
-- Name: unit unit_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.unit ALTER COLUMN unit_id SET DEFAULT nextval('public.unit_unit_id_seq'::regclass);


--
-- Name: users user_id; Type: DEFAULT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.users ALTER COLUMN user_id SET DEFAULT nextval('public.users_user_id_seq'::regclass);


--
-- Data for Name: answer_record; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.answer_record (exam_taking_id, question_id, choice_id, created_at, updated_at) FROM stdin;
1	1	2	2023-06-03 23:25:33.403625	2023-06-03 23:25:33.403625
1	2	7	2023-06-03 23:25:33.447348	2023-06-03 23:25:33.447348
1	3	12	2023-06-03 23:25:33.490134	2023-06-03 23:25:33.490134
1	4	16	2023-06-03 23:25:33.537212	2023-06-03 23:25:33.537212
1	5	20	2023-06-03 23:25:33.583176	2023-06-03 23:25:33.583176
1	6	24	2023-06-03 23:25:33.626708	2023-06-03 23:25:33.626708
1	7	25	2023-06-03 23:25:33.669434	2023-06-03 23:25:33.669434
1	8	28	2023-06-03 23:25:33.712172	2023-06-03 23:25:33.712172
1	9	31	2023-06-03 23:25:33.757542	2023-06-03 23:25:33.757542
1	10	34	2023-06-03 23:25:33.855348	2023-06-03 23:25:33.855348
1	11	37	2023-06-03 23:25:33.897874	2023-06-03 23:25:33.897874
1	12	40	2023-06-03 23:25:33.942782	2023-06-03 23:25:33.942782
1	13	43	2023-06-03 23:25:33.985436	2023-06-03 23:25:33.985436
1	14	46	2023-06-03 23:25:34.028346	2023-06-03 23:25:34.028346
1	15	49	2023-06-03 23:25:34.071362	2023-06-03 23:25:34.071362
1	16	52	2023-06-03 23:25:34.1143	2023-06-03 23:25:34.1143
1	17	55	2023-06-03 23:25:34.156746	2023-06-03 23:25:34.156746
1	18	58	2023-06-03 23:25:34.200396	2023-06-03 23:25:34.200396
1	19	61	2023-06-03 23:25:34.243751	2023-06-03 23:25:34.243751
1	20	64	2023-06-03 23:25:34.288351	2023-06-03 23:25:34.288351
1	21	67	2023-06-03 23:25:34.331057	2023-06-03 23:25:34.331057
1	22	70	2023-06-03 23:25:34.373675	2023-06-03 23:25:34.373675
1	23	73	2023-06-03 23:25:34.425476	2023-06-03 23:25:34.425476
1	24	76	2023-06-03 23:25:34.505531	2023-06-03 23:25:34.505531
1	25	79	2023-06-03 23:25:34.562552	2023-06-03 23:25:34.562552
1	26	82	2023-06-03 23:25:34.606032	2023-06-03 23:25:34.606032
1	27	85	2023-06-03 23:25:34.648501	2023-06-03 23:25:34.648501
1	28	88	2023-06-03 23:25:34.691459	2023-06-03 23:25:34.691459
1	29	91	2023-06-03 23:25:34.738948	2023-06-03 23:25:34.738948
1	30	94	2023-06-03 23:25:34.783719	2023-06-03 23:25:34.783719
1	31	97	2023-06-03 23:25:34.826754	2023-06-03 23:25:34.826754
1	32	100	2023-06-03 23:25:34.873844	2023-06-03 23:25:34.873844
1	33	104	2023-06-03 23:25:34.916672	2023-06-03 23:25:34.916672
1	34	108	2023-06-03 23:25:34.959236	2023-06-03 23:25:34.959236
1	35	112	2023-06-03 23:25:35.00399	2023-06-03 23:25:35.00399
1	36	116	2023-06-03 23:25:35.053543	2023-06-03 23:25:35.053543
1	37	120	2023-06-03 23:25:35.116276	2023-06-03 23:25:35.116276
1	38	124	2023-06-03 23:25:35.160802	2023-06-03 23:25:35.160802
1	39	128	2023-06-03 23:25:35.203422	2023-06-03 23:25:35.203422
1	40	132	2023-06-03 23:25:35.246471	2023-06-03 23:25:35.246471
1	41	136	2023-06-03 23:25:35.289312	2023-06-03 23:25:35.289312
1	42	140	2023-06-03 23:25:35.331987	2023-06-03 23:25:35.331987
1	43	144	2023-06-03 23:25:35.37869	2023-06-03 23:25:35.37869
1	44	148	2023-06-03 23:25:35.426821	2023-06-03 23:25:35.426821
1	45	152	2023-06-03 23:25:35.472197	2023-06-03 23:25:35.472197
1	46	156	2023-06-03 23:25:35.515123	2023-06-03 23:25:35.515123
1	47	160	2023-06-03 23:25:35.557734	2023-06-03 23:25:35.557734
1	48	164	2023-06-03 23:25:35.600417	2023-06-03 23:25:35.600417
1	49	168	2023-06-03 23:25:35.684609	2023-06-03 23:25:35.684609
1	50	172	2023-06-03 23:25:35.727432	2023-06-03 23:25:35.727432
1	51	176	2023-06-03 23:25:35.770341	2023-06-03 23:25:35.770341
1	52	180	2023-06-03 23:25:35.843241	2023-06-03 23:25:35.843241
1	53	184	2023-06-03 23:25:35.892104	2023-06-03 23:25:35.892104
1	54	188	2023-06-03 23:25:35.938968	2023-06-03 23:25:35.938968
1	55	192	2023-06-03 23:25:35.986115	2023-06-03 23:25:35.986115
1	56	196	2023-06-03 23:25:36.028988	2023-06-03 23:25:36.028988
1	57	200	2023-06-03 23:25:36.1045	2023-06-03 23:25:36.1045
1	58	204	2023-06-03 23:25:36.170714	2023-06-03 23:25:36.170714
1	59	208	2023-06-03 23:25:36.213516	2023-06-03 23:25:36.213516
1	60	212	2023-06-03 23:25:36.261153	2023-06-03 23:25:36.261153
1	61	216	2023-06-03 23:25:36.315718	2023-06-03 23:25:36.315718
1	62	220	2023-06-03 23:25:36.362969	2023-06-03 23:25:36.362969
1	63	224	2023-06-03 23:25:36.415831	2023-06-03 23:25:36.415831
1	64	228	2023-06-03 23:25:36.482786	2023-06-03 23:25:36.482786
1	65	232	2023-06-03 23:25:36.532602	2023-06-03 23:25:36.532602
1	66	236	2023-06-03 23:25:36.575146	2023-06-03 23:25:36.575146
1	67	240	2023-06-03 23:25:36.617641	2023-06-03 23:25:36.617641
1	68	244	2023-06-03 23:25:36.660071	2023-06-03 23:25:36.660071
1	69	248	2023-06-03 23:25:36.702773	2023-06-03 23:25:36.702773
1	70	252	2023-06-03 23:25:36.745517	2023-06-03 23:25:36.745517
1	71	256	2023-06-03 23:25:36.789172	2023-06-03 23:25:36.789172
1	72	260	2023-06-03 23:25:36.833413	2023-06-03 23:25:36.833413
1	73	264	2023-06-03 23:25:36.907006	2023-06-03 23:25:36.907006
1	74	268	2023-06-03 23:25:36.9497	2023-06-03 23:25:36.9497
1	75	272	2023-06-03 23:25:36.993856	2023-06-03 23:25:36.993856
1	76	276	2023-06-03 23:25:37.041624	2023-06-03 23:25:37.041624
1	77	280	2023-06-03 23:25:37.08947	2023-06-03 23:25:37.08947
1	78	284	2023-06-03 23:25:37.167285	2023-06-03 23:25:37.167285
1	79	288	2023-06-03 23:25:37.209662	2023-06-03 23:25:37.209662
1	80	292	2023-06-03 23:25:37.253163	2023-06-03 23:25:37.253163
1	81	296	2023-06-03 23:25:37.302468	2023-06-03 23:25:37.302468
1	82	300	2023-06-03 23:25:37.346995	2023-06-03 23:25:37.346995
1	83	304	2023-06-03 23:25:37.393399	2023-06-03 23:25:37.393399
1	84	308	2023-06-03 23:25:37.437037	2023-06-03 23:25:37.437037
1	85	312	2023-06-03 23:25:37.482403	2023-06-03 23:25:37.482403
1	86	316	2023-06-03 23:25:37.525493	2023-06-03 23:25:37.525493
1	87	320	2023-06-03 23:25:37.568674	2023-06-03 23:25:37.568674
1	88	324	2023-06-03 23:25:37.611494	2023-06-03 23:25:37.611494
1	89	328	2023-06-03 23:25:37.65647	2023-06-03 23:25:37.65647
1	90	332	2023-06-03 23:25:37.701595	2023-06-03 23:25:37.701595
1	91	336	2023-06-03 23:25:37.74605	2023-06-03 23:25:37.74605
1	92	340	2023-06-03 23:25:37.801948	2023-06-03 23:25:37.801948
1	93	344	2023-06-03 23:25:37.859055	2023-06-03 23:25:37.859055
1	94	348	2023-06-03 23:25:37.914353	2023-06-03 23:25:37.914353
1	95	352	2023-06-03 23:25:37.957649	2023-06-03 23:25:37.957649
1	96	356	2023-06-03 23:25:38.001422	2023-06-03 23:25:38.001422
1	97	360	2023-06-03 23:25:38.046977	2023-06-03 23:25:38.046977
1	98	364	2023-06-03 23:25:38.090166	2023-06-03 23:25:38.090166
1	99	368	2023-06-03 23:25:38.132506	2023-06-03 23:25:38.132506
1	100	372	2023-06-03 23:25:38.183024	2023-06-03 23:25:38.183024
1	101	376	2023-06-03 23:25:38.22781	2023-06-03 23:25:38.22781
1	102	380	2023-06-03 23:25:38.270093	2023-06-03 23:25:38.270093
1	103	384	2023-06-03 23:25:38.316064	2023-06-03 23:25:38.316064
1	104	388	2023-06-03 23:25:38.399364	2023-06-03 23:25:38.399364
1	105	392	2023-06-03 23:25:38.447257	2023-06-03 23:25:38.447257
1	106	396	2023-06-03 23:25:38.531195	2023-06-03 23:25:38.531195
1	107	400	2023-06-03 23:25:38.579124	2023-06-03 23:25:38.579124
1	108	404	2023-06-03 23:25:38.63255	2023-06-03 23:25:38.63255
1	109	408	2023-06-03 23:25:38.675029	2023-06-03 23:25:38.675029
1	110	412	2023-06-03 23:25:38.720743	2023-06-03 23:25:38.720743
1	111	416	2023-06-03 23:25:38.767008	2023-06-03 23:25:38.767008
1	112	420	2023-06-03 23:25:38.809596	2023-06-03 23:25:38.809596
1	113	424	2023-06-03 23:25:38.85967	2023-06-03 23:25:38.85967
1	114	428	2023-06-03 23:25:38.904046	2023-06-03 23:25:38.904046
1	115	432	2023-06-03 23:25:38.946966	2023-06-03 23:25:38.946966
1	116	436	2023-06-03 23:25:38.993114	2023-06-03 23:25:38.993114
1	117	440	2023-06-03 23:25:39.03743	2023-06-03 23:25:39.03743
1	118	444	2023-06-03 23:25:39.117537	2023-06-03 23:25:39.117537
1	119	448	2023-06-03 23:25:39.200145	2023-06-03 23:25:39.200145
1	120	452	2023-06-03 23:25:39.242479	2023-06-03 23:25:39.242479
1	121	456	2023-06-03 23:25:39.292442	2023-06-03 23:25:39.292442
1	122	460	2023-06-03 23:25:39.342943	2023-06-03 23:25:39.342943
1	123	464	2023-06-03 23:25:39.388569	2023-06-03 23:25:39.388569
1	124	468	2023-06-03 23:25:39.43112	2023-06-03 23:25:39.43112
1	125	472	2023-06-03 23:25:39.474017	2023-06-03 23:25:39.474017
1	126	476	2023-06-03 23:25:39.516745	2023-06-03 23:25:39.516745
1	127	480	2023-06-03 23:25:39.559603	2023-06-03 23:25:39.559603
1	128	484	2023-06-03 23:25:39.603398	2023-06-03 23:25:39.603398
1	129	488	2023-06-03 23:25:39.743133	2023-06-03 23:25:39.743133
1	130	492	2023-06-03 23:25:39.805371	2023-06-03 23:25:39.805371
1	131	496	2023-06-03 23:25:39.872611	2023-06-03 23:25:39.872611
1	132	500	2023-06-03 23:25:39.916852	2023-06-03 23:25:39.916852
1	133	504	2023-06-03 23:25:39.959558	2023-06-03 23:25:39.959558
1	134	508	2023-06-03 23:25:40.002304	2023-06-03 23:25:40.002304
1	135	512	2023-06-03 23:25:40.050979	2023-06-03 23:25:40.050979
1	136	516	2023-06-03 23:25:40.094525	2023-06-03 23:25:40.094525
1	137	520	2023-06-03 23:25:40.136975	2023-06-03 23:25:40.136975
1	138	524	2023-06-03 23:25:40.18863	2023-06-03 23:25:40.18863
1	139	528	2023-06-03 23:25:40.231103	2023-06-03 23:25:40.231103
1	140	532	2023-06-03 23:25:40.274489	2023-06-03 23:25:40.274489
1	141	536	2023-06-03 23:25:40.320145	2023-06-03 23:25:40.320145
1	142	540	2023-06-03 23:25:40.385369	2023-06-03 23:25:40.385369
1	143	544	2023-06-03 23:25:40.447125	2023-06-03 23:25:40.447125
1	144	548	2023-06-03 23:25:40.493839	2023-06-03 23:25:40.493839
1	145	552	2023-06-03 23:25:40.53641	2023-06-03 23:25:40.53641
1	146	556	2023-06-03 23:25:40.599369	2023-06-03 23:25:40.599369
1	147	560	2023-06-03 23:25:40.644305	2023-06-03 23:25:40.644305
1	148	564	2023-06-03 23:25:40.689041	2023-06-03 23:25:40.689041
1	149	568	2023-06-03 23:25:40.732001	2023-06-03 23:25:40.732001
1	150	572	2023-06-03 23:25:40.775136	2023-06-03 23:25:40.775136
1	151	576	2023-06-03 23:25:40.876214	2023-06-03 23:25:40.876214
1	152	580	2023-06-03 23:25:40.925498	2023-06-03 23:25:40.925498
1	153	584	2023-06-03 23:25:40.970981	2023-06-03 23:25:40.970981
1	154	588	2023-06-03 23:25:41.014079	2023-06-03 23:25:41.014079
1	155	592	2023-06-03 23:25:41.134313	2023-06-03 23:25:41.134313
1	156	596	2023-06-03 23:25:41.234326	2023-06-03 23:25:41.234326
1	157	600	2023-06-03 23:25:41.334315	2023-06-03 23:25:41.334315
1	158	604	2023-06-03 23:25:41.434394	2023-06-03 23:25:41.434394
1	159	608	2023-06-03 23:25:41.534454	2023-06-03 23:25:41.534454
1	160	612	2023-06-03 23:25:41.638957	2023-06-03 23:25:41.638957
1	161	616	2023-06-03 23:25:41.734317	2023-06-03 23:25:41.734317
1	162	620	2023-06-03 23:25:41.834317	2023-06-03 23:25:41.834317
1	163	624	2023-06-03 23:25:41.934706	2023-06-03 23:25:41.934706
1	164	628	2023-06-03 23:25:41.977627	2023-06-03 23:25:41.977627
1	165	632	2023-06-03 23:25:42.020633	2023-06-03 23:25:42.020633
1	166	636	2023-06-03 23:25:42.077297	2023-06-03 23:25:42.077297
1	167	640	2023-06-03 23:25:42.128437	2023-06-03 23:25:42.128437
1	168	644	2023-06-03 23:25:42.171129	2023-06-03 23:25:42.171129
1	169	648	2023-06-03 23:25:42.215617	2023-06-03 23:25:42.215617
1	170	652	2023-06-03 23:25:42.334351	2023-06-03 23:25:42.334351
1	171	656	2023-06-03 23:25:42.377763	2023-06-03 23:25:42.377763
1	172	660	2023-06-03 23:25:42.425126	2023-06-03 23:25:42.425126
1	173	664	2023-06-03 23:25:42.534372	2023-06-03 23:25:42.534372
1	174	668	2023-06-03 23:25:42.584848	2023-06-03 23:25:42.584848
1	175	672	2023-06-03 23:25:42.630195	2023-06-03 23:25:42.630195
1	176	676	2023-06-03 23:25:42.67263	2023-06-03 23:25:42.67263
1	177	680	2023-06-03 23:25:42.715123	2023-06-03 23:25:42.715123
1	178	684	2023-06-03 23:25:42.83434	2023-06-03 23:25:42.83434
1	179	688	2023-06-03 23:25:42.934336	2023-06-03 23:25:42.934336
1	180	692	2023-06-03 23:25:43.034332	2023-06-03 23:25:43.034332
1	181	696	2023-06-03 23:25:43.158436	2023-06-03 23:25:43.158436
1	182	700	2023-06-03 23:25:43.201046	2023-06-03 23:25:43.201046
1	183	704	2023-06-03 23:25:43.244105	2023-06-03 23:25:43.244105
1	184	708	2023-06-03 23:25:43.286455	2023-06-03 23:25:43.286455
1	185	712	2023-06-03 23:25:43.329437	2023-06-03 23:25:43.329437
1	186	716	2023-06-03 23:25:43.373009	2023-06-03 23:25:43.373009
1	187	720	2023-06-03 23:25:43.415601	2023-06-03 23:25:43.415601
1	188	724	2023-06-03 23:25:43.458579	2023-06-03 23:25:43.458579
1	189	728	2023-06-03 23:25:43.501471	2023-06-03 23:25:43.501471
1	190	732	2023-06-03 23:25:43.546996	2023-06-03 23:25:43.546996
1	191	736	2023-06-03 23:25:43.589496	2023-06-03 23:25:43.589496
1	192	740	2023-06-03 23:25:43.631816	2023-06-03 23:25:43.631816
1	193	744	2023-06-03 23:25:43.693483	2023-06-03 23:25:43.693483
1	194	748	2023-06-03 23:25:43.74695	2023-06-03 23:25:43.74695
1	195	752	2023-06-03 23:25:43.791475	2023-06-03 23:25:43.791475
1	196	756	2023-06-03 23:25:43.838774	2023-06-03 23:25:43.838774
1	197	760	2023-06-03 23:25:43.883204	2023-06-03 23:25:43.883204
1	198	764	2023-06-03 23:25:43.925768	2023-06-03 23:25:43.925768
1	199	768	2023-06-03 23:25:43.968322	2023-06-03 23:25:43.968322
1	200	772	2023-06-03 23:25:44.011138	2023-06-03 23:25:44.011138
\.


--
-- Data for Name: api_address; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_address (id, created_at, updated_at, email, phone, full_name, province, province_code, district, district_code, ward, ward_code, street, created_by_id) FROM stdin;
1	2023-06-24 07:00:59.5883+00	2023-06-24 07:00:59.588323+00	pttu2902@gmail.com	0987654321	Thanh Tú Phan	Thành phố Hồ Chí Minh	79	Thành phố Thủ Đức	769	Phường Linh Trung	26800	32/10	3
\.


--
-- Data for Name: api_cartitem; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_cartitem (id, created_at, updated_at, qty, created_by_id, product_id, variation_id) FROM stdin;
2	2023-06-24 07:02:19.35901+00	2023-06-24 07:02:19.35905+00	1	3	6	24
\.


--
-- Data for Name: api_category; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_category (id, created_at, updated_at, name, "desc", img_url, is_deleted) FROM stdin;
1	2023-06-23 13:10:29.467628+00	2023-06-23 13:11:24.200185+00	Sofas & sectionals	Sit back and relax. It’s one of life’s simple pleasures, and it’s all about personal comfort. With a sofa and armchair, everyone in the family can get comfortable. We have all sorts of cozy and affordable sofas to choose from, so you can find a seating solution to sink into that matches a look you love, too.	https://www.ikea.com/global/assets/range-categorisation/images/sofas-fu003.jpeg	f
2	2023-06-23 13:12:05.522612+00	2023-06-23 13:12:05.522636+00	Armchairs & accent chairs	The new PERSBOL armchair has crafted details and a timeless design – a simple yet striking way to add character to any room. Designer Nike Karlsson says, “The traditional design creates a sense of familiarity, and the wood adds a warm and genuine feel, while the expression is light and airy.”	https://www.ikea.com/global/assets/range-categorisation/images/armchairs-chaise-longues-fu006.jpeg	f
3	2023-06-23 13:20:18.714903+00	2023-06-23 13:20:18.71493+00	Dressers & storage drawers	A chest of drawers that suits you, your clothes and your space means no more cold mornings searching for your socks. Ours come in styles that match our wardrobes and in different sizes so you can use them around your home, for instance a tall chest of drawers in a narrow hall.	https://www.ikea.com/us/en/range-categorisation/images/dressers-storage-drawers-st004.jpeg	f
4	2023-06-23 13:20:51.74658+00	2023-06-23 13:20:51.746613+00	Beds	There are lots of beds, but feeling good when you wake up starts with finding the right one. Choose one that’s big enough to stretch out, but cozy enough to snuggle up tight. Our affordable beds and bed frames are built to last for years – in a style that you’ll love just as long.	https://www.ikea.com/us/en/range-categorisation/images/beds-bm003.jpeg	f
5	2023-06-23 13:21:51.449474+00	2023-06-23 13:21:51.449522+00	Tables & desks	Gather around the table and hear the family news, play a game, help with homework or set your stuff down. With our desks & tables in a wide range of sizes and styles, you’ll find one that fits whatever you want to do in whatever space you have. You can find a table online or test them out in our stores.	https://www.ikea.com/global/assets/range-categorisation/images/tables-desks-fu004.jpeg	f
6	2023-06-23 13:22:24.342433+00	2023-06-23 13:22:24.342458+00	Chairs	Ensure that you, your family, friends and guests always have a multitude of comfortable seating options throughout your home with IKEA’s extensive collection of chairs. Our selection features chairs to match the décor and size of every room in your home, including stylish accent chairs, super comfortable recliners, space saving folding chairs, elegant dining chairs and much more. Browse our collection today and make sure the floor is never anyone’s favorite place to sit in your home.	https://www.ikea.com/global/assets/range-categorisation/images/chairs-fu002.jpeg	f
7	2023-06-23 13:23:18.699206+00	2023-06-23 13:23:18.699237+00	Shelves	Smart solutions in storage and shelving have the versatility of simply getting things out of the way or putting them on display and within easy reach. Whatever the need in any room, you’ll be adding lots of style to your shelf organization.	https://www.ikea.com/global/assets/range-categorisation/images/bookcases-shelving-units-st002.jpeg	f
8	2023-06-23 13:24:48.424143+00	2023-06-23 13:24:48.42417+00	Dining furniture	A simple way to make everyday meals feel all the more special? Enjoy them al fresco on comfortable outdoor dining sets. Dining under the sun and sky elevates simple dishes (and leftovers!) into an unforgettable meal.	https://www.ikea.com/global/assets/range-categorisation/images/dining-furniture-700417.jpeg	f
\.


--
-- Data for Name: api_favoriteitem; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_favoriteitem (id, created_at, updated_at, created_by_id, product_id) FROM stdin;
1	2023-06-24 06:52:31.333333+00	2023-06-24 06:52:31.333358+00	3	6
2	2023-06-24 06:52:32.137473+00	2023-06-24 06:52:32.137499+00	3	5
\.


--
-- Data for Name: api_order; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_order (id, created_at, updated_at, phone, full_name, province, province_code, district, district_code, ward, ward_code, street, status, total, payment, created_by_id, email, shipping_date, voucher_id) FROM stdin;
1	2023-06-24 07:02:02.939807+00	2023-06-24 07:06:12.849476+00	0987654321	Thanh Tú Phan	Thành phố Hồ Chí Minh	79	Thành phố Thủ Đức	769	Phường Linh Trung	26800	32/10	Success	1408.00	Mastercard Tú Phan	3	pttu2902@gmail.com	\N	\N
\.


--
-- Data for Name: api_orderdetail; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_orderdetail (id, created_at, updated_at, price, qty, order_id, variation_id, product_id) FROM stdin;
1	2023-06-24 07:02:03.035543+00	2023-06-24 07:02:03.035569+00	699.00	2	1	24	6
\.


--
-- Data for Name: api_payment; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_payment (id, created_at, updated_at, name, exp, provider_id, created_by_id, number, cvc) FROM stdin;
1	2023-06-24 07:01:47.820482+00	2023-06-24 07:01:47.820506+00	Tú Phan	2025-03-31	2	3	1234432145678765	333
\.


--
-- Data for Name: api_paymentprovider; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_paymentprovider (id, created_at, updated_at, is_deleted, img_url, name, method) FROM stdin;
1	2023-05-30 02:49:34.220175+00	2023-05-30 02:49:34.220175+00	f	https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Fvisa.png?alt=media&token=6f33f581-ac3a-4308-8dd3-3badd6d84110&_gl=1*15xjzlo*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTY1NjIuMC4wLjA.	Visa	Card
2	2023-05-30 02:49:34.220175+00	2023-05-30 02:49:34.220175+00	f	https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Fmastercard.png?alt=media&token=e27221d4-d12d-4653-9b73-00dd43227c97&_gl=1*1bqu0uz*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTY3NTguMC4wLjA.	Mastercard	Card
3	2023-05-30 02:49:34.220175+00	2023-05-30 02:49:34.220175+00	f	https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Fjcb.png?alt=media&token=63161821-0dd9-4a0a-b7e9-98d21085bd17&_gl=1*1uampi0*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTY5NDkuMC4wLjA.	JCB	Card
4	2023-05-30 02:49:34.220175+00	2023-05-30 02:49:34.220175+00	f	https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Famerican_express.png?alt=media&token=89ed60a2-d479-4f58-9b3c-3dbb592b09da&_gl=1*1bt6mtu*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTY5OTcuMC4wLjA.	American Express	Card
5	2023-05-30 02:49:34.220175+00	2023-05-30 02:49:34.220175+00	f	https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Fmomo.png?alt=media&token=c5b60b50-81b6-47b1-b887-383e8ade7690&_gl=1*y1rmcs*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTcyMTAuMC4wLjA.	Momo	E-Wallet
6	2023-05-30 02:49:34.220175+00	2023-05-30 02:49:34.220175+00	f	https://firebasestorage.googleapis.com/v0/b/evaware-893a5.appspot.com/o/payment_providers%2Fatm.png?alt=media&token=185e3eb1-b48b-4c35-80d6-7a1f016c5d88&_gl=1*ixz4m9*_ga*MTUxMjk3ODk4Ni4xNjg0MDU1ODkw*_ga_CW55HF8NVT*MTY4NTQxNTg4Ni4yOS4xLjE2ODU0MTcyNjQuMC4wLjA.	ATM	Domestic ATM Card
\.


--
-- Data for Name: api_product; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_product (id, created_at, updated_at, name, "desc", price, thumbnail, category_id, reviews_count, is_deleted, avg_rating, variations_count, discount, material, length, height, more_info, weight, width) FROM stdin;
3	2023-06-24 05:47:50.102616+00	2023-06-24 05:47:50.102639+00	PÄRUP	Sofa, Vissle gray	499.00	https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__1041907_pe841187_s5.jpg?f=s	1	0	f	0.0	4	0	Wood	120.00	65.00	Timeless design with delicate details such as piping around the armrests and wooden legs.	0.90	29.00
1	2023-06-24 05:47:14.412122+00	2023-06-24 05:47:14.412157+00	FRIHETEN	Sleeper sectional,3 seat w/storage, Skiftebo dark gray	899.00	https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0175610_pe328883_s5.jpg?f=s	1	0	f	0.0	5	0	Fiberboard	29.00	88.00	This sofa converts quickly and easily into a spacious bed when you remove the back cushions and pull out the underframe.	15.00	29.00
16	2023-06-24 06:04:39.381174+00	2023-06-24 06:04:39.381199+00	MALM	6-drawer dresser, black-brown,	299.99	https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__0484881_pe621345_s5.jpg?f=s	3	0	f	0.0	4	0	Polyester	15.00	170.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	1.10	29.00
13	2023-06-24 06:01:34.942338+00	2023-06-24 06:01:34.942362+00	JÄTTEBO	Cover 1.5-seat module with storage, Samsala dark yellow-green	70.00	https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-samsala-dark-yellow-green__1109575_pe870065_s5.jpg?f=s	2	0	f	0.0	3	0	Polyester	65.00	170.00	This cover is made from Samsala, an extra-wide-wale and strong corduroy fabric with soft comfort and an expression that adds character to the room.	5.00	90.00
4	2023-06-24 05:52:33.058623+00	2023-06-24 05:52:33.058646+00	KIVIK	Sofa with chaise, Tibbleby beige/gray	1149.00	https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056147_pe848280_s5.jpg?f=s	1	0	f	0.0	5	0	Fiberboard	120.00	77.00	Enjoy the super comfy KIVIK sofa with deep seat cushions made of pocket springs, high resilience foam and polyester fibers – adding both firm support and relaxing softness.	15.00	45.00
11	2023-06-24 06:01:00.17052+00	2023-06-24 06:01:00.170544+00	FLINSHULT	Armchair, Djuparp dark green	549.00	https://www.ikea.com/us/en/images/products/flinshult-armchair-djuparp-dark-green__0980371_pe814912_s5.jpg?f=s	2	0	f	0.0	4	0	Fiberboard	65.00	77.00	This armchair is ideal for sitting and reading because the high back and wide seat make it extra comfortable to curl up in.	1.20	120.00
5	2023-06-24 05:52:50.067775+00	2023-06-24 05:52:50.067805+00	GLOSTAD	Loveseat, Knisa dark gray	149.00	https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0950864_pe800736_s5.jpg?f=s	1	0	f	0.0	2	0	Glass	90.00	88.00	GLOSTAD sofa has a simple design which is also comfortable with its thick seat, padded armrests and soft back cushions that sit firmly in place.	5.00	50.00
2	2023-06-24 05:47:30.184739+00	2023-06-24 05:47:30.184761+00	UPPLAND	Sofa, Blekinge white	849.00	https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0818565_pe774487_s5.jpg?f=s	1	0	f	0.0	7	0	Fiberboard	88.00	30.00	Enjoy the super comfy UPPLAND sofa with embracing feel and deep seat cushions made of pocket springs, high resilience foam and polyester fibers, adding both firm support and relaxing softness.	1.20	90.00
9	2023-06-24 05:58:23.051385+00	2023-06-24 05:58:23.051408+00	POÄNG	Armchair, brown/Skiftebo dark gray	139.00	https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0937022_pe793528_s5.jpg?f=s	2	0	f	0.0	7	0	Fiberboard	29.00	77.00	Layer-glued bent oak gives comfortable resilience.	0.90	15.00
15	2023-06-24 06:04:29.933304+00	2023-06-24 06:04:29.933328+00	HEMNES	8-drawer dresser, white stain,	399.99	https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0627346_pe693299_s5.jpg?f=s	3	0	f	0.0	3	0	Glass	50.00	80.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	0.90	120.00
6	2023-06-24 05:52:57.742966+00	2023-06-24 05:52:57.74299+00	PÄRUP	Sofa with chaise, Vissle gray	699.00	https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-gray__1041911_pe841191_s5.jpg?f=s	1	0	f	0.0	4	0	Fiberboard	65.00	80.00	Timeless design with delicate details such as piping around the armrests and wooden legs.	0.50	45.00
8	2023-06-24 05:57:55.347496+00	2023-06-24 05:57:55.347523+00	STRANDMON	Wing chair, Nordvalla dark gray	369.00	https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0325432_pe517964_s5.jpg?f=s	2	0	f	0.0	8	0	Glass	15.00	40.00	You can really loosen up and relax in comfort because the high back on this chair provides extra support for your neck.	0.50	88.00
10	2023-06-24 06:00:53.042754+00	2023-06-24 06:00:53.042779+00	EKENÄSET	Armchair, Kilanda light beige	249.00	https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__1109687_pe870153_s5.jpg?f=s	2	0	f	0.0	2	0	Wood	45.00	75.00	Clean lines and supportive comfort, regardless if you’re reading, socializing with friends or just relaxing for a moment.	1.90	29.00
12	2023-06-24 06:01:13.145986+00	2023-06-24 06:01:13.146014+00	UPPLAND	Armchair, Hallarp beige	529.00	https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-beige__0818468_pe774420_s5.jpg?f=s	2	0	f	0.0	7	0	Wood	65.00	170.00	Enjoy the super comfy UPPLAND armchair with embracing feel and deep seat cushion made of pocket springs, high resilience foam and polyester fibers, adding both firm support and relaxing softness.	15.00	90.00
14	2023-06-24 06:04:13.433802+00	2023-06-24 06:04:13.433842+00	MALM	6-drawer dresser, white,	299.99	https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0484884_pe621348_s5.jpg?f=s	3	0	f	0.0	4	0	Fiberboard	50.00	40.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	2.00	90.00
17	2023-06-24 06:04:49.27694+00	2023-06-24 06:04:49.276962+00	KULLEN	6-drawer dresser, black-brown,	149.99	https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__0651638_pe706983_s5.jpg?f=s	3	0	f	0.0	2	0	Polyester	50.00	77.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	2.00	15.00
18	2023-06-24 06:04:57.84276+00	2023-06-24 06:04:57.842783+00	KOPPANG	6-drawer dresser, white,	259.99	https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__0651639_pe706984_s5.jpg?f=s	3	0	f	0.0	2	0	Fiberboard	120.00	75.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	1.90	45.00
19	2023-06-24 06:05:06.412805+00	2023-06-24 06:05:06.412831+00	MALM	4-drawer chest, white,	199.99	https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__0484879_pe621344_s5.jpg?f=s	3	0	f	0.0	4	0	Glass	29.00	77.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	0.50	77.00
24	2023-06-24 06:07:33.972715+00	2023-06-24 06:07:33.972739+00	BRIMNES	Bed frame with storage, white/Luröy,	399.00	https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__1151024_pe884762_s5.jpg?f=s	4	0	f	0.0	3	0	Polyester	15.00	80.00	Ample storage space is hidden neatly under the bed in 4 large drawers. Perfect for storing duvets, pillows and bed linen.	5.00	120.00
25	2023-06-24 06:07:48.782654+00	2023-06-24 06:07:48.782676+00	KLEPPSTAD	Bed frame, white/Vissle beige,	199.00	https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035340_pe840527_s5.jpg?f=s	4	0	f	0.0	1	0	Glass	29.00	40.00	The clean and simple design goes well with other bedroom furniture and fits perfectly in any modern bedroom.	0.90	65.00
20	2023-06-24 06:06:19.272327+00	2023-06-24 06:06:19.272349+00	MALM	Bed frame, high, black-brown/Luröy,	349.00	https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0638608_pe699032_s5.jpg?f=s	4	0	f	0.0	4	0	Wood	77.00	75.00	Wood veneer gives you the same look, feel and beauty as solid wood with unique variations in grain, color and texture.	4.00	77.00
21	2023-06-24 06:06:46.378607+00	2023-06-24 06:06:46.378631+00	MALM	High bed frame/2 storage boxes, black-brown/Luröy,	449.00	https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__1154412_pe886059_s5.jpg?f=s	4	0	f	0.0	4	0	Fiberboard	15.00	40.00	Ample storage space is hidden neatly under the bed in 2 large drawers. Perfect for storing duvets, pillows and bed linen.	4.00	45.00
22	2023-06-24 06:07:05.082412+00	2023-06-24 06:07:05.082447+00	NEIDEN	Bed frame, pine,	59.00	https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__0749131_pe745500_s5.jpg?f=s	4	0	f	0.0	1	0	Wood	65.00	40.00	The compact design is perfect for tight spaces or under low ceilings, so you can make the most of your available space.	15.00	77.00
26	2023-06-24 06:10:09.063022+00	2023-06-24 06:10:09.063046+00	MICKE	Desk, white,	99.99	https://www.ikea.com/us/en/images/products/micke-desk-white__0736018_pe740345_s5.jpg?f=s	5	0	f	0.0	4	0	Polyester	88.00	40.00	It’s easy to keep cords and cables out of sight but close at hand with the cable outlet at the back.	0.50	65.00
23	2023-06-24 06:07:14.5065+00	2023-06-24 06:07:14.506523+00	SAGSTUA	Bed frame, black/Luröy,	249.00	https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0662135_pe719104_s5.jpg?f=s	4	0	f	0.0	4	0	Fiberboard	29.00	40.00	Brass-colored details on the headboard, footboard and legs give a unique twist to this classic design.	5.00	50.00
32	2023-06-24 06:12:40.228803+00	2023-06-24 06:12:40.228825+00	POÄNG	Armchair, birch veneer/Knisa light beige	129.00	https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0571500_pe666933_s5.jpg?f=s	6	0	f	0.0	7	0	Fiberboard	45.00	65.00	The layer-glued bent wood frame gives the armchair a comfortable resilience, making it perfect to relax in.	2.00	90.00
31	2023-06-24 06:11:45.106727+00	2023-06-24 06:11:45.106748+00	ALEX	Drawer unit, white,	110.00	https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0977775_pe813763_s5.jpg?f=s	5	0	f	0.0	3	0	Wood	29.00	170.00	Drawer stops prevent the drawer from being pulled out too far.	4.00	88.00
28	2023-06-24 06:10:49.903854+00	2023-06-24 06:10:49.903881+00	LAGKAPTEN	Tabletop, gray/turquoise,	59.99	https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207325_pe911159_s5.jpg?f=s	5	0	f	0.0	5	0	Glass	65.00	75.00	The plywood-patterned edge band adds to the quality feel.	15.00	90.00
35	2023-06-24 06:13:32.643019+00	2023-06-24 06:13:32.643044+00	ADDE	Chair, white	20.00	https://www.ikea.com/us/en/images/products/adde-chair-white__0728280_pe736170_s5.jpg?f=s	6	0	f	0.0	2	0	Glass	50.00	65.00	You can stack the chairs, so they take less space when you're not using them.	1.90	50.00
27	2023-06-24 06:10:23.15856+00	2023-06-24 06:10:23.158582+00	LAGKAPTEN / ALEX	Desk, white,	279.99	https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__1022432_pe832720_s5.jpg?f=s	5	0	f	0.0	7	0	Wood	88.00	80.00	The table top is made of board-on-frame, a strong and lightweight material.	4.00	50.00
29	2023-06-24 06:11:16.414679+00	2023-06-24 06:11:16.414705+00	LINNMON / ADILS	Table, white,	54.99	https://www.ikea.com/us/en/images/products/linnmon-adils-table-white__0737165_pe740925_s5.jpg?f=s	5	0	f	0.0	4	0	Fiberboard	77.00	170.00	Pre-drilled leg holes for easy assembly.	0.90	77.00
33	2023-06-24 06:13:14.399356+00	2023-06-24 06:13:14.399383+00	LIDÅS	Chair, black/Sefast black	55.00	https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167042_pe891344_s5.jpg?f=s	6	0	f	0.0	3	0	Wood	50.00	88.00	You decide the style of your chair. The seat shell is available in different colors, and the underframe SEFAST is available in white, black and chrome-plated colors.	4.00	45.00
30	2023-06-24 06:11:36.099699+00	2023-06-24 06:11:36.099724+00	MICKE	Desk, white,	119.99	https://www.ikea.com/us/en/images/products/micke-desk-white__0736020_pe740347_s5.jpg?f=s	5	0	f	0.0	2	0	Wood	88.00	30.00	A long table top makes it easy to create a workspace for two.	5.00	29.00
34	2023-06-24 06:13:24.981751+00	2023-06-24 06:13:24.981776+00	ÖSTANÖ	Chair, red-brown Remmarn/red-brown	25.00	https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1120081_pe873713_s5.jpg?f=s	6	0	f	0.0	2	0	Polyester	65.00	75.00	With sofa-comfort feel, this chair can also serve as cosy extra seating in your bedroom, hallway, living room or wherever you would like a comfy spot to relax without taking up too much space.	1.90	90.00
38	2023-06-24 06:15:59.736307+00	2023-06-24 06:15:59.736331+00	KALLAX	Shelf unit, white,	89.99	https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__0644757_pe702939_s5.jpg?f=s	7	0	f	0.0	5	0	Glass	90.00	80.00	The simple design with clean lines makes KALLAX flexible and easy to use at home.	0.90	77.00
40	2023-06-24 06:16:38.746906+00	2023-06-24 06:16:38.74693+00	BAGGEBO	Shelf unit, metal/white,	24.99	https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__0981562_pe815396_s5.jpg?f=s	7	0	f	0.0	1	0	Polyester	29.00	40.00	The metal frame and mesh shelves make a nice and practical place for your books, decorations and other things that you like.	1.10	120.00
36	2023-06-24 06:13:41.454789+00	2023-06-24 06:13:41.454813+00	TEODORES	Chair, white	45.00	https://www.ikea.com/us/en/images/products/teodores-chair-white__0727344_pe735616_s5.jpg?f=s	6	0	f	0.0	4	0	Polyester	50.00	29.00	The chair is easy to store when not in use, since you can stack up to 6 chairs on top of each other.	1.20	50.00
37	2023-06-24 06:14:00.763742+00	2023-06-24 06:14:00.763766+00	KYRRE	Stool, bright blue	24.99	https://www.ikea.com/us/en/images/products/kyrre-stool-bright-blue__1181813_pe896805_s5.jpg?f=s	6	0	f	0.0	5	0	Glass	65.00	30.00	This all-round stool with three bent legs comes to rescue when unexpected guests pop by or you need an extra space to place your book or drink.	0.90	90.00
39	2023-06-24 06:16:20.388157+00	2023-06-24 06:16:20.388183+00	KALLAX	Shelf unit with 4 inserts, white,	169.99	https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__0754627_pe747994_s5.jpg?f=s	7	0	f	0.0	4	0	Glass	45.00	77.00	A simple unit can be enough storage for a limited space or the foundation for a larger storage solution if your needs change.	0.50	88.00
45	2023-06-24 06:18:42.150873+00	2023-06-24 06:18:42.150898+00	SKOGSTA	Dining table, acacia,	549.00	https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0546603_pe656255_s5.jpg?f=s	8	0	f	0.0	1	0	Glass	90.00	80.00	Acacia has a rich brown color and distinctive grain pattern. It is highly durable, resistant to scratches and water, ideal for heavy-use. Acacia slightly darkens with age.	1.90	29.00
41	2023-06-24 06:16:44.538296+00	2023-06-24 06:16:44.538318+00	BILLY	Bookcase, white,	49.00	https://www.ikea.com/us/en/images/products/billy-bookcase-white__0644260_pe702536_s5.jpg?f=s	7	0	f	0.0	3	0	Polyester	88.00	75.00	Narrow shelves help you use small wall spaces effectively by accommodating small items in a minimum of space.	0.90	90.00
46	2023-06-24 06:18:47.715294+00	2023-06-24 06:18:47.715316+00	VOXLÖV / VOXLÖV	Table and 4 chairs, bamboo/bamboo,	899.99	https://www.ikea.com/us/en/images/products/voxloev-voxloev-table-and-4-chairs-bamboo-bamboo__0926660_pe789444_s5.jpg?f=s	8	0	f	0.0	1	0	Glass	29.00	77.00	The angled back of the chair, as well as generously sized and curved seat/back offer restful support and comfort while eating, writing, or doing paperwork.	4.00	120.00
42	2023-06-24 06:16:59.03332+00	2023-06-24 06:16:59.033344+00	LACK	Wall shelf unit, white,	99.99	https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white__0246565_pe385541_s5.jpg?f=s	7	0	f	0.0	3	0	Wood	15.00	77.00	Shallow shelves help you to use the walls in your home efficiently. They hold a lot of things without taking up much space in the room.	0.50	45.00
47	2023-06-24 06:18:53.288022+00	2023-06-24 06:18:53.288053+00	MELLTORP / LIDÅS	Table and 4 chairs, white white/black/black,	319.99	https://www.ikea.com/us/en/images/products/melltorp-lidas-table-and-4-chairs-white-white-black-black__1176225_pe894967_s5.jpg?f=s	8	0	f	0.0	1	0	Glass	15.00	77.00	The table is very sturdy thanks to the metal frame.	2.00	90.00
48	2023-06-24 06:18:58.332049+00	2023-06-24 06:18:58.332081+00	SKOGSTA / NORDVIKEN	Table and 6 chairs, acacia/black,	999.00	https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__1097254_pe864851_s5.jpg?f=s	8	0	f	0.0	1	0	Polyester	50.00	29.00	Every table is unique, with varying grain pattern and natural color shifts that are part of the charm of wood.	0.50	90.00
49	2023-06-24 06:19:03.066375+00	2023-06-24 06:19:03.066397+00	LISABO / LISABO	Table and 4 chairs, ash veneer/ash,	589.99	https://www.ikea.com/us/en/images/products/lisabo-lisabo-table-and-4-chairs-ash-veneer-ash__0921113_pe787668_s5.jpg?f=s	8	0	f	0.0	2	0	Polyester	120.00	40.00	Ash is a strong hardwood material with a beautiful grain pattern. As it ages the color deepens moderately towards a deep straw color.	1.20	15.00
43	2023-06-24 06:17:12.558867+00	2023-06-24 06:17:12.558899+00	KALLAX	Shelving unit with underframe, white/white,	119.99	https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-white-white__1041422_pe841007_s5.jpg?f=s	7	0	f	0.0	8	0	Glass	120.00	88.00	The simple design with clean lines makes KALLAX flexible and easy to use at home.	5.00	29.00
44	2023-06-24 06:18:23.660013+00	2023-06-24 06:18:23.660038+00	JOKKMOKK	Table and 4 chairs, antique stain	249.99	https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-antique-stain__0736929_pe740809_s5.jpg?f=s	8	0	f	0.0	2	0	Glass	88.00	40.00	Easy to bring home since the whole dining set is packed in one box.	4.00	88.00
\.


--
-- Data for Name: api_review; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_review (id, created_at, updated_at, content, rating, created_by_id, variation_id, product_id, img_urls) FROM stdin;
\.


--
-- Data for Name: api_usedvoucher; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_usedvoucher (id, created_at, updated_at, user_id, voucher_id) FROM stdin;
\.


--
-- Data for Name: api_variation; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_variation (id, created_at, updated_at, inventory, name, img_urls, product_id, is_deleted) FROM stdin;
1	2023-06-24 05:47:25.184189+00	2023-06-24 05:47:25.184212+00	20	dark gray	{https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0175610_pe328883_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0779005_ph163058_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__1089881_pe861727_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0779007_ph163064_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0779006_ph163062_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0833845_pe603738_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0833847_pe604692_s5.jpg?f=s}	1	f
2	2023-06-24 05:47:25.504125+00	2023-06-24 05:47:25.504158+00	20	black	{https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0248337_pe386785_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0727225_pe735670_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0829726_pe600308_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0732486_pe738637_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0829731_pe603749_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0829730_pe602871_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0829733_pe604690_s5.jpg?f=s}	1	f
3	2023-06-24 05:47:26.033218+00	2023-06-24 05:47:26.033242+00	20	beige	{https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0690253_pe723174_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0690251_pe723175_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__1184604_ph179194_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0690249_pe723173_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0690250_pe723177_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0690247_pe723171_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0787554_pe763281_s5.jpg?f=s}	1	f
4	2023-06-24 05:47:26.440967+00	2023-06-24 05:47:26.440992+00	20	dark gray	{https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690261_pe723182_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690259_pe723183_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690260_pe723184_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__1089879_pe861725_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690257_pe723181_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690258_pe723180_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690255_pe723178_s5.jpg?f=s}	1	f
5	2023-06-24 05:47:26.76847+00	2023-06-24 05:47:26.768491+00	20	blue	{https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690243_pe723167_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690241_pe723168_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__1089880_pe861726_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690242_pe723169_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690238_pe723165_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690239_pe723166_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690240_pe723170_s5.jpg?f=s}	1	f
6	2023-06-24 05:47:44.139192+00	2023-06-24 05:47:44.139456+00	20	white	{https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0818565_pe774487_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0818564_pe774486_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0818534_pe774464_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0261000_pe404970_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0739096_pe225167_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0934662_pe792483_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0937793_pe793848_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0252533_pe391799_s5.jpg?f=s}	2	f
7	2023-06-24 05:47:44.480802+00	2023-06-24 05:47:44.480824+00	20	beige	{https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0818569_pe774497_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0818568_pe774490_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0818541_pe774472_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0929127_pe790146_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0934663_pe792484_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0937794_pe793849_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0928381_pe789853_s5.jpg?f=s}	2	f
8	2023-06-24 05:47:45.036707+00	2023-06-24 05:47:45.036731+00	20	gray	{https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0818567_pe774489_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0818566_pe774488_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0818537_pe774468_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0929128_pe790147_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0939196_pe794479_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0934664_pe792485_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0818497_pe774439_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0948958_pe799429_s5.jpg?f=s}	2	f
9	2023-06-24 05:47:45.4671+00	2023-06-24 05:47:45.467124+00	20	gray	{https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0924992_pe788686_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0924993_pe788685_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0929129_pe790150_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0818543_pe774474_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0939197_pe794482_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0934665_pe792489_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0818503_pe774445_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0948958_pe799429_s5.jpg?f=s}	2	f
10	2023-06-24 05:47:45.963631+00	2023-06-24 05:47:45.963663+00	20	dark gray	{https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0818571_pe774493_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0818570_pe774492_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0818546_pe774477_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0934666_pe792487_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0818506_pe774448_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0928381_pe789853_s5.jpg?f=s}	2	f
11	2023-06-24 05:47:46.254491+00	2023-06-24 05:47:46.254514+00	20	beige	{https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0818573_pe774495_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0818572_pe774494_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0818549_pe774480_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0929130_pe790149_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0939198_pe794481_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0934667_pe792488_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0818509_pe774451_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0948958_pe799429_s5.jpg?f=s}	2	f
12	2023-06-24 05:47:46.622607+00	2023-06-24 05:47:46.62263+00	20	red	{https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0818575_pe774491_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0818574_pe774496_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0929131_pe790148_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0939199_pe794480_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0934668_pe792486_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0937799_pe793851_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0928381_pe789853_s5.jpg?f=s}	2	f
13	2023-06-24 05:47:57.438919+00	2023-06-24 05:47:57.438944+00	20	gray	{https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__1041907_pe841187_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0989588_pe818557_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0985853_pe816837_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0985836_pe816822_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0985845_pe816830_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0985826_pe816814_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0985851_pe816836_s5.jpg?f=s}	3	f
14	2023-06-24 05:47:57.717957+00	2023-06-24 05:47:57.717983+00	20	red	{https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__1041904_pe841184_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__0950178_pe800193_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__0950102_pe800231_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__0950105_pe800216_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__0950104_pe800215_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__1134558_pe878804_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__1108787_pe869620_s5.jpg?f=s}	3	f
15	2023-06-24 05:47:58.065416+00	2023-06-24 05:47:58.065441+00	20	dark gray	{https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__1041905_pe841185_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__0950180_pe800199_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__0950108_pe800218_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__0950110_pe800219_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__0950109_pe800228_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__1134558_pe878804_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__1108787_pe869620_s5.jpg?f=s}	3	f
16	2023-06-24 05:47:58.399639+00	2023-06-24 05:47:58.399667+00	20	green	{https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__1041906_pe841186_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__0950182_pe800197_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__0986556_pe817203_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__0950112_pe800229_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__0950115_pe800222_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__1167242_ph189245_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__0950114_pe800230_s5.jpg?f=s}	3	f
25	2023-06-24 05:53:03.643667+00	2023-06-24 05:53:03.643692+00	20	red	{https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-beige__1041908_pe841188_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-beige__0950140_pe800160_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-beige__0950141_pe800161_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-beige__0950105_pe800216_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-beige__0950104_pe800215_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-beige__1134558_pe878804_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-beige__1108788_pe869619_s5.jpg?f=s}	6	f
17	2023-06-24 05:52:43.783909+00	2023-06-24 05:52:43.783931+00	20	gray	{https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056147_pe848280_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056146_pe848281_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056136_pe848268_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056148_pe848279_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1148199_ph184927_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056137_pe848269_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056135_pe848267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1134553_pe878803_s5.jpg?f=s}	4	f
18	2023-06-24 05:52:44.030821+00	2023-06-24 05:52:44.030843+00	20	red	{https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0479956_pe619108_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0777309_pe758514_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0814739_ph166240_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0675090_ph146135_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0675091_ph146134_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0777016_pe758410_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0821977_pe625075_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0914082_pe783835_s5.jpg?f=s}	4	f
19	2023-06-24 05:52:44.449728+00	2023-06-24 05:52:44.449755+00	20	gray	{https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055847_pe848125_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055846_pe848126_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055792_pe848103_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055845_pe848124_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1148204_ph184815_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055811_pe848114_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055810_pe848112_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1134553_pe878803_s5.jpg?f=s}	4	f
20	2023-06-24 05:52:44.888025+00	2023-06-24 05:52:44.888049+00	20	dark gray	{https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__1124126_pe875027_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__1124124_pe875028_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__1124220_pe875082_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__1124125_pe875029_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__1134553_pe878803_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__0914082_pe783835_s5.jpg?f=s}	4	f
21	2023-06-24 05:52:45.218978+00	2023-06-24 05:52:45.219+00	20	beige	{https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__1124123_pe875030_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__1124121_pe875025_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__1124219_pe875083_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__1124122_pe875026_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__1134553_pe878803_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__0914082_pe783835_s5.jpg?f=s}	4	f
22	2023-06-24 05:52:53.241354+00	2023-06-24 05:52:53.241506+00	20	dark gray	{https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0950864_pe800736_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0982867_pe815771_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__1059523_ph180677_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0987393_pe817515_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0987395_pe817517_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0950897_pe800737_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0987394_pe817516_s5.jpg?f=s}	5	f
23	2023-06-24 05:52:53.541263+00	2023-06-24 05:52:53.541287+00	20	blue	{https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0950900_pe800740_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0981841_pe815495_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0950902_pe800742_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0987358_pe817503_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0987359_pe817504_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__1059524_ph179219_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0950901_pe800741_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0950903_pe800739_s5.jpg?f=s}	5	f
26	2023-06-24 05:53:03.973756+00	2023-06-24 05:53:03.973779+00	20	dark gray	{https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-dark-gray__1041909_pe841189_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-dark-gray__1206462_ph177968_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-dark-gray__1206461_ph178912_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-dark-gray__1206463_ph177966_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-dark-gray__0950144_pe800170_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-dark-gray__0950110_pe800219_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-dark-gray__0950109_pe800228_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-gunnared-dark-gray__1134558_pe878804_s5.jpg?f=s}	6	f
27	2023-06-24 05:53:04.366621+00	2023-06-24 05:53:04.366645+00	20	green	{https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-dark-green__1041910_pe841190_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-dark-green__0950146_pe800166_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-dark-green__0986556_pe817203_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-dark-green__0950147_pe800167_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-dark-green__0950112_pe800229_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-dark-green__0950115_pe800222_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-dark-green__0950114_pe800230_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-dark-green__1108788_pe869619_s5.jpg?f=s}	6	f
28	2023-06-24 05:58:13.046969+00	2023-06-24 05:58:13.046991+00	20	dark gray	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0325432_pe517964_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__1116445_pe872501_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0750991_ph159256_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0813424_ph166295_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0836847_pe596292_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0836845_pe583755_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0325435_pe517963_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0712904_pe729117_s5.jpg?f=s}	8	f
29	2023-06-24 05:58:13.306005+00	2023-06-24 05:58:13.306029+00	20	blue	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__1127756_pe876319_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__1127755_pe876320_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__1127752_pe876317_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__1127753_pe876318_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__1127754_pe876321_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__0963366_pe808498_s5.jpg?f=s}	8	f
30	2023-06-24 05:58:14.878617+00	2023-06-24 05:58:14.878642+00	20	green	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0531313_pe647261_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0841150_pe647266_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0570380_ph145743_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0739102_ph152847_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0739101_ph155488_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0813427_ph166293_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0841141_pe647262_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0841145_pe647264_s5.jpg?f=s}	8	f
31	2023-06-24 05:58:16.454314+00	2023-06-24 05:58:16.454339+00	20	red	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-red-brown__1127697_pe876309_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-red-brown__1127751_pe876314_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-red-brown__1127748_pe876313_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-red-brown__1127749_pe876316_s5.jpg?f=s}	8	f
32	2023-06-24 05:58:17.074487+00	2023-06-24 05:58:17.074508+00	20	beige	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0950941_pe800821_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__1059566_ph179098_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0950943_pe800826_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0950946_pe800823_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0950944_pe800824_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0950945_pe800825_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0963366_pe808498_s5.jpg?f=s}	8	f
33	2023-06-24 05:58:17.795674+00	2023-06-24 05:58:17.795698+00	20	blue	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kvillsfors-dark-blue-blue__0961698_pe807715_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kvillsfors-dark-blue-blue__0986935_pe817415_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kvillsfors-dark-blue-blue__0961699_pe807716_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kvillsfors-dark-blue-blue__0961700_pe807720_s5.jpg?f=s}	8	f
34	2023-06-24 05:58:18.217317+00	2023-06-24 05:58:18.217342+00	20	yellow	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0325450_pe517970_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0837297_pe601176_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0913860_ph145337_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__1184561_ph179968_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0813426_ph166290_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0837286_pe596513_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0837284_pe583756_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0325452_pe517969_s5.jpg?f=s}	8	f
35	2023-06-24 05:58:18.576356+00	2023-06-24 05:58:18.576391+00	20	black	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__0761768_pe751434_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__0930013_ph168645_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__1184555_ph186827_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__0761769_pe751435_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__0813433_ph166294_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__1184562_ph167261_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__1184563_ph167300_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__0963366_pe808498_s5.jpg?f=s}	8	f
36	2023-06-24 05:58:35.669447+00	2023-06-24 05:58:35.669472+00	20	dark gray	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0937022_pe793528_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0937023_pe793529_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0937024_pe793530_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0937025_pe793531_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0612906_pe686092_s5.jpg?f=s}	9	f
37	2023-06-24 06:00:46.235758+00	2023-06-24 06:00:46.235791+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0497150_pe628977_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0837589_pe629093_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0837587_pe628980_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0837584_pe628979_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0837772_pe629026_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0612906_pe686092_s5.jpg?f=s}	9	f
38	2023-06-24 06:00:46.598593+00	2023-06-24 06:00:46.598616+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0497155_pe628982_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0840717_pe631653_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0840713_pe628985_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0840708_pe628984_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0841343_pe629031_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0612906_pe686092_s5.jpg?f=s}	9	f
39	2023-06-24 06:00:46.931176+00	2023-06-24 06:00:46.931198+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0497160_pe628987_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0837235_pe629100_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0837233_pe628990_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0837232_pe628989_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0840815_pe629036_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0612906_pe686092_s5.jpg?f=s}	9	f
40	2023-06-24 06:00:47.393546+00	2023-06-24 06:00:47.393571+00	20	black	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-black__0571538_pe666953_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-black__0840687_pe666956_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-black__0840685_pe666955_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-black__0840683_pe666954_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-black__0617563_pe688046_s5.jpg?f=s}	9	f
41	2023-06-24 06:00:47.71781+00	2023-06-24 06:00:47.717832+00	20	beige	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-light-beige__0571543_pe666957_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-light-beige__0840421_pe666960_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-light-beige__0840414_pe666959_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-light-beige__0840409_pe666958_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-light-beige__0617563_pe688046_s5.jpg?f=s}	9	f
42	2023-06-24 06:00:48.020286+00	2023-06-24 06:00:48.020311+00	20	yellow	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-yellow__0936998_pe793510_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-yellow__0936999_pe793511_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-yellow__0937000_pe793512_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-yellow__0937001_pe793513_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-yellow__0612906_pe686092_s5.jpg?f=s}	9	f
43	2023-06-24 06:00:55.933655+00	2023-06-24 06:00:55.933691+00	20	beige	{https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__1109687_pe870153_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__1179060_pe895831_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__1110707_pe870568_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__1109720_pe870187_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__0940909_pe795235_s5.jpg?f=s}	10	f
44	2023-06-24 06:00:56.243309+00	2023-06-24 06:00:56.243341+00	20	gray	{https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__1109684_pe870150_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__1179059_pe895832_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__1109682_pe870149_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__1177527_ph189208_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__1109721_pe870188_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__0940909_pe795235_s5.jpg?f=s}	10	f
45	2023-06-24 06:01:07.106715+00	2023-06-24 06:01:07.106737+00	20	green	{https://www.ikea.com/us/en/images/products/flinshult-armchair-djuparp-dark-green__0980371_pe814912_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-djuparp-dark-green__0980372_pe814915_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-djuparp-dark-green__0980373_pe814914_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-djuparp-dark-green__0980374_pe814913_s5.jpg?f=s}	11	f
46	2023-06-24 06:01:07.446069+00	2023-06-24 06:01:07.446108+00	20	beige	{https://www.ikea.com/us/en/images/products/flinshult-armchair-beige__1010600_pe828156_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-beige__1010601_pe828157_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-beige__1010603_pe828159_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-beige__1010602_pe828160_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-beige__1010604_pe828158_s5.jpg?f=s}	11	f
47	2023-06-24 06:01:07.943142+00	2023-06-24 06:01:07.943168+00	20	brown	{https://www.ikea.com/us/en/images/products/flinshult-armchair-brown-beige__0980367_pe814908_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-brown-beige__0980368_pe814911_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-brown-beige__0980369_pe814910_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-brown-beige__0980370_pe814909_s5.jpg?f=s}	11	f
48	2023-06-24 06:01:08.499278+00	2023-06-24 06:01:08.499317+00	20	dark gray	{https://www.ikea.com/us/en/images/products/flinshult-armchair-gunnared-dark-gray__0980376_pe814918_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-gunnared-dark-gray__0980377_pe814921_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-gunnared-dark-gray__0980378_pe814920_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/flinshult-armchair-gunnared-dark-gray__0980379_pe814919_s5.jpg?f=s}	11	f
49	2023-06-24 06:01:27.57415+00	2023-06-24 06:01:27.574172+00	20	beige	{https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-beige__0818468_pe774420_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-beige__0818470_pe774427_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-beige__0818469_pe774426_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-beige__0944724_pe797416_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-beige__0818501_pe774443_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-beige__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-beige__0925674_pe788822_s5.jpg?f=s}	12	f
50	2023-06-24 06:01:27.971597+00	2023-06-24 06:01:27.97162+00	20	white	{https://www.ikea.com/us/en/images/products/uppland-armchair-blekinge-white__24278_pe109112_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-blekinge-white__0818464_pe774419_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-blekinge-white__0818462_pe774422_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-blekinge-white__0261000_pe404970_s5.jpg?f=s}	12	f
51	2023-06-24 06:01:28.342915+00	2023-06-24 06:01:28.342941+00	20	gray	{https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-gray__0818467_pe774418_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-gray__0818466_pe774425_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-gray__0818465_pe774424_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-gray__0939196_pe794479_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-gray__0944727_pe797409_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-gray__0818497_pe774439_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-gray__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-hallarp-gray__0925674_pe788822_s5.jpg?f=s}	12	f
52	2023-06-24 06:01:28.747027+00	2023-06-24 06:01:28.747059+00	20	gray	{https://www.ikea.com/us/en/images/products/uppland-armchair-remmarn-light-gray__0818473_pe774430_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-remmarn-light-gray__0818472_pe774429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-remmarn-light-gray__0818471_pe774428_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-remmarn-light-gray__0944730_pe797419_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-remmarn-light-gray__0818503_pe774445_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-remmarn-light-gray__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-remmarn-light-gray__0925674_pe788822_s5.jpg?f=s}	12	f
53	2023-06-24 06:01:29.024153+00	2023-06-24 06:01:29.024175+00	20	dark gray	{https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-dark-turquoise__0818476_pe774411_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-dark-turquoise__0818475_pe774412_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-dark-turquoise__0818474_pe774421_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-dark-turquoise__0944733_pe797403_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-dark-turquoise__0818506_pe774448_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-dark-turquoise__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-dark-turquoise__0925674_pe788822_s5.jpg?f=s}	12	f
54	2023-06-24 06:01:29.559136+00	2023-06-24 06:01:29.559163+00	20	beige	{https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-light-beige__0818479_pe774414_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-light-beige__0818478_pe774413_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-light-beige__0818477_pe774431_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-light-beige__0939198_pe794481_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-light-beige__0944724_pe797416_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-light-beige__0818501_pe774443_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-light-beige__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-totebo-light-beige__0925674_pe788822_s5.jpg?f=s}	12	f
55	2023-06-24 06:01:29.842583+00	2023-06-24 06:01:29.842606+00	20	red	{https://www.ikea.com/us/en/images/products/uppland-armchair-virestad-red-white__0818482_pe774417_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-virestad-red-white__0818481_pe774416_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-virestad-red-white__0818480_pe774415_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-virestad-red-white__0929131_pe790148_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-virestad-red-white__0944739_pe797411_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-virestad-red-white__0937799_pe793851_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-virestad-red-white__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-armchair-virestad-red-white__0925674_pe788822_s5.jpg?f=s}	12	f
56	2023-06-24 06:01:40.290838+00	2023-06-24 06:01:40.290862+00	20	green	{https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-samsala-dark-yellow-green__1109575_pe870065_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-samsala-dark-yellow-green__1109646_pe870136_s5.jpg?f=s}	13	f
57	2023-06-24 06:01:40.859907+00	2023-06-24 06:01:40.859931+00	20	gray	{https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-samsala-gray-beige__1109578_pe870066_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-samsala-gray-beige__1109648_pe870137_s5.jpg?f=s}	13	f
58	2023-06-24 06:01:41.751006+00	2023-06-24 06:01:41.751032+00	20	gray	{https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-tonerud-gray__1109576_pe870068_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-tonerud-gray__1105034_pe868006_s5.jpg?f=s}	13	f
59	2023-06-24 06:04:21.759082+00	2023-06-24 06:04:21.759106+00	20	white	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0484884_pe621348_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__1154415_pe886018_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0823861_pe775996_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0823862_pe775997_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__1154235_pe885954_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0772164_pe755890_s5.jpg?f=s}	14	f
60	2023-06-24 06:04:22.445417+00	2023-06-24 06:04:22.445455+00	20	brown	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__0484881_pe621345_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154385_pe886014_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154387_pe886016_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154386_pe886017_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154229_pe885950_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__0772164_pe755890_s5.jpg?f=s}	14	f
61	2023-06-24 06:04:23.144298+00	2023-06-24 06:04:23.144322+00	20	gray	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0750592_pe746789_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154608_pe886229_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154609_pe886231_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154610_pe886230_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0750586_pe746784_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0772164_pe755890_s5.jpg?f=s}	14	f
62	2023-06-24 06:04:23.938942+00	2023-06-24 06:04:23.938967+00	20	white	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0484883_pe621346_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154416_pe886019_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154418_pe886020_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154417_pe886021_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0381120_pe555870_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0772164_pe755890_s5.jpg?f=s}	14	f
63	2023-06-24 06:04:34.795509+00	2023-06-24 06:04:34.795532+00	20	white	{https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0627346_pe693299_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0858919_pe554983_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0385043_pe557593_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0380725_pe555604_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0251043_pe389676_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__1093041_pe863159_s5.jpg?f=s}	15	f
64	2023-06-24 06:04:35.152375+00	2023-06-24 06:04:35.152399+00	20	brown	{https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__0627349_pe693302_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__0132796_pe193829_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__0385084_pe557634_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__0380367_pe555288_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__0585252_ph143039_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__1093041_pe863159_s5.jpg?f=s}	15	f
65	2023-06-24 06:04:35.502027+00	2023-06-24 06:04:35.502058+00	20	dark gray	{https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-dark-gray-stained__0519831_pe641793_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-dark-gray-stained__0519832_pe641792_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-dark-gray-stained__0520151_pe642029_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-dark-gray-stained__1093041_pe863159_s5.jpg?f=s}	15	f
102	2023-06-24 06:10:44.41151+00	2023-06-24 06:10:44.411543+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__1022395_pe832706_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__0977796_pe813779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__0977775_pe813763_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__1160033_pe888711_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__1045546_pe842654_s5.jpg?f=s}	27	f
66	2023-06-24 06:04:44.407951+00	2023-06-24 06:04:44.407977+00	20	brown	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__0484881_pe621345_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154385_pe886014_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154387_pe886016_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154386_pe886017_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154229_pe885950_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__0772164_pe755890_s5.jpg?f=s}	16	f
67	2023-06-24 06:04:44.697238+00	2023-06-24 06:04:44.697271+00	20	gray	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0750592_pe746789_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154608_pe886229_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154609_pe886231_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154610_pe886230_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0750586_pe746784_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0772164_pe755890_s5.jpg?f=s}	16	f
68	2023-06-24 06:04:45.065615+00	2023-06-24 06:04:45.065637+00	20	white	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0484884_pe621348_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__1154415_pe886018_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0823861_pe775996_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0823862_pe775997_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__1154235_pe885954_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0772164_pe755890_s5.jpg?f=s}	16	f
69	2023-06-24 06:04:45.436827+00	2023-06-24 06:04:45.436859+00	20	white	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0484883_pe621346_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154416_pe886019_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154418_pe886020_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154417_pe886021_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0381120_pe555870_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0772164_pe755890_s5.jpg?f=s}	16	f
70	2023-06-24 06:04:52.155095+00	2023-06-24 06:04:52.155118+00	20	brown	{https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__0651638_pe706983_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__0778046_pe758818_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__0795347_pe766006_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__0393835_pe562520_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__1092611_pe862935_s5.jpg?f=s}	17	f
71	2023-06-24 06:04:53.139054+00	2023-06-24 06:04:53.139077+00	20	white	{https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-white__0651643_pe706985_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-white__0778050_pe758820_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-white__0795348_pe766005_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-white__0393321_pe562522_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-white__1092611_pe862935_s5.jpg?f=s}	17	f
72	2023-06-24 06:05:01.446757+00	2023-06-24 06:05:01.446781+00	20	white	{https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__0651639_pe706984_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__0778092_pe758833_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__0858121_pe661804_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__0778096_pe758834_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__1092597_pe862930_s5.jpg?f=s}	18	f
73	2023-06-24 06:05:02.24114+00	2023-06-24 06:05:02.241165+00	20	brown	{https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-black-brown__0430434_pe584637_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-black-brown__0778088_pe758832_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-black-brown__0857866_pe661805_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-black-brown__0778102_pe758835_s5.jpg?f=s}	18	f
74	2023-06-24 06:05:13.542939+00	2023-06-24 06:05:13.542962+00	20	white	{https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__0484879_pe621344_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__1154335_pe885995_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__1154336_pe885994_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__0823860_pe775995_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__1154235_pe885954_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__0757046_pe749103_s5.jpg?f=s}	19	f
75	2023-06-24 06:05:13.834369+00	2023-06-24 06:05:13.834394+00	20	brown	{https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-black-brown__0484876_pe621355_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-black-brown__0858161_pe624308_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-black-brown__0490153_pe624309_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-black-brown__1154229_pe885950_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-black-brown__0757046_pe749103_s5.jpg?f=s}	19	f
76	2023-06-24 06:05:14.333361+00	2023-06-24 06:05:14.333385+00	20	gray	{https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__0750599_pe746792_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__1154602_pe886225_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__1154604_pe886226_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__1154603_pe886228_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__0750586_pe746784_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__0757046_pe749103_s5.jpg?f=s}	19	f
77	2023-06-24 06:05:14.689276+00	2023-06-24 06:05:14.689301+00	20	white	{https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__1154347_pe886002_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__1154349_pe886001_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__1154346_pe886003_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__1154345_pe886004_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__0381120_pe555870_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__0757046_pe749103_s5.jpg?f=s}	19	f
78	2023-06-24 06:06:25.221285+00	2023-06-24 06:06:25.22131+00	20	brown	{https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0638608_pe699032_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__1101514_pe866693_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0452610_ph133272_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__1092102_pe863044_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__1092103_pe863019_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0860721_pe566695_s5.jpg?f=s}	20	f
79	2023-06-24 06:06:30.666298+00	2023-06-24 06:06:30.66632+00	20	gray	{https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__0775049_pe756805_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__1101570_pe866745_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__1092106_pe863020_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__1092107_pe863021_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__0775046_pe756804_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__0750596_pe746791_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__0722727_pe733696_s5.jpg?f=s}	20	f
80	2023-06-24 06:06:31.343022+00	2023-06-24 06:06:31.343047+00	20	white	{https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__0749130_pe745499_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__0800857_ph163673_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__1101527_pe866706_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__1101528_pe866707_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__1101529_pe866708_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__0860683_pe566696_s5.jpg?f=s}	20	f
81	2023-06-24 06:06:32.138857+00	2023-06-24 06:06:32.138881+00	20	white	{https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__0637598_pe698416_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__1101531_pe866710_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__0734386_pe739457_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__1101532_pe866711_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__1101533_pe866712_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__0410923_pe577789_s5.jpg?f=s}	20	f
82	2023-06-24 06:06:53.88285+00	2023-06-24 06:06:53.882874+00	20	brown	{https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__1154412_pe886059_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__0735708_pe740106_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__1101552_pe866728_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__1101553_pe866678_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__1092103_pe863019_s5.jpg?f=s}	21	f
83	2023-06-24 06:06:54.738749+00	2023-06-24 06:06:54.73878+00	20	gray	{https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1154411_pe886058_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1101595_pe866768_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__0785993_pe762843_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1101596_pe866681_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1092107_pe863021_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1154410_pe886057_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1154409_pe886056_s5.jpg?f=s}	21	f
84	2023-06-24 06:07:00.031748+00	2023-06-24 06:07:00.031774+00	20	white	{https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__1154393_pe886042_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__0800857_ph163673_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__1101597_pe866769_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__1101598_pe866682_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__1101529_pe866708_s5.jpg?f=s}	21	f
85	2023-06-24 06:07:00.388378+00	2023-06-24 06:07:00.388412+00	20	white	{https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__1154398_pe886037_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__1101591_pe866765_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__0803797_ph163207_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__0800868_ph162809_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__1101592_pe866766_s5.jpg?f=s}	21	f
86	2023-06-24 06:07:05.633616+00	2023-06-24 06:07:05.633646+00	20	dark gray	{https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__0749131_pe745500_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__1102024_pe866848_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__1102025_pe866849_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__0859802_pe664779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__0751533_pe747074_s5.jpg?f=s}	22	f
87	2023-06-24 06:07:21.550449+00	2023-06-24 06:07:21.550473+00	20	dark gray	{https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0662135_pe719104_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__1101999_pe866818_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0800859_ph163664_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0734518_pe739490_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0738465_pe741457_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__1102000_pe866826_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__1102001_pe866827_s5.jpg?f=s}	23	f
88	2023-06-24 06:07:22.87108+00	2023-06-24 06:07:22.871103+00	20	dark gray	{https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__0662135_pe719104_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__1101999_pe866818_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__0800859_ph163664_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__0734518_pe739490_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__0738465_pe741457_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__1102000_pe866826_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__1102001_pe866827_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__0861931_pe719102_s5.jpg?f=s}	23	f
89	2023-06-24 06:07:23.545902+00	2023-06-24 06:07:23.545927+00	20	dark gray	{https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__0662135_pe719104_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__1101999_pe866818_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__0800859_ph163664_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__0734518_pe739490_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__0738465_pe741457_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__1102000_pe866826_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__1102001_pe866827_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__0861931_pe719102_s5.jpg?f=s}	23	f
90	2023-06-24 06:07:23.896992+00	2023-06-24 06:07:23.897014+00	20	dark gray	{https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__0662176_pe719097_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__1101963_pe866780_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__1101964_pe866781_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__1101965_pe866782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__0861838_pe719098_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__0861814_pe713130_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__0861829_pe713131_s5.jpg?f=s}	23	f
91	2023-06-24 06:07:42.541694+00	2023-06-24 06:07:42.541718+00	20	white	{https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__1151024_pe884762_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__1101953_pe866879_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__0800869_ph163683_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__0966529_ph175105_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__1101954_pe866880_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__0860776_pe659486_s5.jpg?f=s}	24	f
92	2023-06-24 06:07:43.237971+00	2023-06-24 06:07:43.237999+00	20	black	{https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__1151031_pe884735_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__1177947_pe895553_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__1101984_pe866796_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__0861220_pe659473_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__0780657_pe760158_s5.jpg?f=s}	24	f
146	2023-06-24 06:16:15.080046+00	2023-06-24 06:16:15.080068+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-high-gloss-white__0627096_pe693189_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-high-gloss-white__1051323_pe845146_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-high-gloss-white__1102294_pe866903_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-high-gloss-white__1215327_pe911964_s5.jpg?f=s}	38	f
93	2023-06-24 06:07:43.617713+00	2023-06-24 06:07:43.617735+00	20	gray	{https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0817188_pe773895_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0820603_pe775071_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0817187_pe773896_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0817186_pe773894_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0780657_pe760158_s5.jpg?f=s}	24	f
94	2023-06-24 06:07:49.228532+00	2023-06-24 06:07:49.228557+00	20	dark gray	{https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035340_pe840527_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035341_pe840528_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035343_pe840530_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035342_pe840529_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1116343_pe872489_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035350_pe840525_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035344_pe840531_s5.jpg?f=s}	25	f
95	2023-06-24 06:10:17.118647+00	2023-06-24 06:10:17.11867+00	20	white	{https://www.ikea.com/us/en/images/products/micke-desk-white__0736018_pe740345_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0746525_ph151482_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0773258_ph161164_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0802383_ph161320_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0851508_pe565256_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0851516_pe573416_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0403463_pe565522_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0526706_pe645107_s5.jpg?f=s}	26	f
96	2023-06-24 06:10:17.432442+00	2023-06-24 06:10:17.432475+00	20	red	{https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0921882_pe787985_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0921883_pe787986_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0973784_ph175180_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0973786_ph175187_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0973785_ph175189_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0921885_pe787992_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0921884_pe787987_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0526706_pe645107_s5.jpg?f=s}	26	f
97	2023-06-24 06:10:17.799781+00	2023-06-24 06:10:17.799802+00	20	brown	{https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0735981_pe740299_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0798268_ph165484_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0798267_ph165486_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0798266_ph165487_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0798269_ph165483_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0403204_pe565263_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0748280_ph144536_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0526706_pe645107_s5.jpg?f=s}	26	f
98	2023-06-24 06:10:18.087412+00	2023-06-24 06:10:18.087438+00	20	white	{https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0921886_pe787989_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0921887_pe787990_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0973767_ph175190_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0973768_ph175202_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0973769_ph175196_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0921889_pe787988_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0921888_pe787991_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0526706_pe645107_s5.jpg?f=s}	26	f
99	2023-06-24 06:10:43.613459+00	2023-06-24 06:10:43.613481+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__1022432_pe832720_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__0977800_pe813782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__0977775_pe813763_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__1158868_pe888215_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__1045546_pe842654_s5.jpg?f=s}	27	f
100	2023-06-24 06:10:43.880618+00	2023-06-24 06:10:43.88064+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown__1022394_pe832705_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown__0977796_pe813779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown__0977786_pe813770_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown__1160031_pe888710_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown__1045546_pe842654_s5.jpg?f=s}	27	f
101	2023-06-24 06:10:44.136398+00	2023-06-24 06:10:44.136422+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-gray-turquoise__1022396_pe832707_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-gray-turquoise__0977796_pe813779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-gray-turquoise__0977774_pe813762_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-gray-turquoise__1160034_pe888714_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-gray-turquoise__1045546_pe842654_s5.jpg?f=s}	27	f
158	2023-06-24 06:17:07.691141+00	2023-06-24 06:17:07.691177+00	20	white	{https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white-stained-oak-effect__0670332_pe715459_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white-stained-oak-effect__1092777_pe863046_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white-stained-oak-effect__0670331_pe715458_s5.jpg?f=s}	42	f
103	2023-06-24 06:10:44.761312+00	2023-06-24 06:10:44.761334+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184928_pe898140_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184855_pe898113_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184962_pe898180_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1186815_pe898949_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184964_pe898178_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184961_pe898177_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184927_pe898141_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1045546_pe842654_s5.jpg?f=s}	27	f
104	2023-06-24 06:10:45.194846+00	2023-06-24 06:10:45.194871+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__1022433_pe832721_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__0977800_pe813782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__0977786_pe813770_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__1045546_pe842654_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__1160047_pe888724_s5.jpg?f=s}	27	f
105	2023-06-24 06:10:45.571765+00	2023-06-24 06:10:45.571787+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-gray-turquoise__1022434_pe832718_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-gray-turquoise__0977800_pe813782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-gray-turquoise__0977774_pe813762_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-gray-turquoise__1160048_pe888725_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-gray-turquoise__1045546_pe842654_s5.jpg?f=s}	27	f
106	2023-06-24 06:11:01.654943+00	2023-06-24 06:11:01.654967+00	20	gray	{https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207325_pe911159_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207323_pe907921_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207320_pe907918_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207321_pe907919_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207322_pe907922_s5.jpg?f=s}	28	f
107	2023-06-24 06:11:02.355098+00	2023-06-24 06:11:02.355123+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-tabletop-black-brown__0977796_pe813779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-black-brown__1028369_pe835306_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-black-brown__1160157_pe888780_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-black-brown__1103201_pe867210_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-black-brown__1160036_pe888715_s5.jpg?f=s}	28	f
108	2023-06-24 06:11:07.799093+00	2023-06-24 06:11:07.799117+00	20	green	{https://www.ikea.com/us/en/images/products/lagkapten-tabletop-light-green__1073229_pe855663_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-light-green__1073225_pe855661_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-light-green__1078933_pe857334_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-light-green__1078936_pe857335_s5.jpg?f=s}	28	f
109	2023-06-24 06:11:09.804597+00	2023-06-24 06:11:09.804619+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white__0977800_pe813782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white__1166683_ph182444_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white__1166682_ph184478_s5.jpg?f=s}	28	f
110	2023-06-24 06:11:10.121634+00	2023-06-24 06:11:10.12166+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1184858_pe898114_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1184855_pe898113_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1184962_pe898180_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1186815_pe898949_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1184964_pe898178_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1184961_pe898177_s5.jpg?f=s}	28	f
111	2023-06-24 06:11:25.411705+00	2023-06-24 06:11:25.411738+00	20	white	{https://www.ikea.com/us/en/images/products/linnmon-adils-table-white__0737165_pe740925_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white__0734654_pe739562_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white__0734621_pe739540_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white__1009784_pe827741_s5.jpg?f=s}	29	f
112	2023-06-24 06:11:25.707021+00	2023-06-24 06:11:25.707049+00	20	brown	{https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown__0974302_pe812345_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown__0734653_pe739561_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown__0734618_pe739551_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown__1009784_pe827741_s5.jpg?f=s}	29	f
113	2023-06-24 06:11:26.140943+00	2023-06-24 06:11:26.140966+00	20	brown	{https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown-white__0974303_pe812346_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown-white__0734653_pe739561_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown-white__0734621_pe739540_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown-white__1009784_pe827741_s5.jpg?f=s}	29	f
114	2023-06-24 06:11:26.573533+00	2023-06-24 06:11:26.573557+00	20	black	{https://www.ikea.com/us/en/images/products/linnmon-adils-table-white-black__0737166_pe740909_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white-black__0734654_pe739562_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white-black__0734618_pe739551_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white-black__1009784_pe827741_s5.jpg?f=s}	29	f
115	2023-06-24 06:11:39.793683+00	2023-06-24 06:11:39.793708+00	20	white	{https://www.ikea.com/us/en/images/products/micke-desk-white__0736020_pe740347_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0798273_ph165490_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0798274_ph165491_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0982364_ph175923_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0982365_ph175924_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0851288_pe565258_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0403484_pe565543_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0403543_pe565602_s5.jpg?f=s}	30	f
116	2023-06-24 06:11:40.230184+00	2023-06-24 06:11:40.230207+00	20	brown	{https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0736019_pe740346_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0403166_pe565225_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0851562_pe573386_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0403528_pe565587_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0403462_pe565521_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__1045437_pe842611_s5.jpg?f=s}	30	f
117	2023-06-24 06:11:57.3747+00	2023-06-24 06:11:57.374725+00	20	white	{https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0977775_pe813763_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__1043718_ph167220_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0995650_ph172911_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0995610_pe821781_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0995620_pe821790_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0993390_pe820897_s5.jpg?f=s}	31	f
118	2023-06-24 06:12:03.138222+00	2023-06-24 06:12:03.138247+00	20	brown	{https://www.ikea.com/us/en/images/products/alex-drawer-unit-black-brown__0977786_pe813770_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-black-brown__1158870_pe888217_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-black-brown__0995608_pe821779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-black-brown__0476104_pe616052_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-black-brown__0993390_pe820897_s5.jpg?f=s}	31	f
119	2023-06-24 06:12:03.750946+00	2023-06-24 06:12:03.750971+00	20	gray	{https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__0977774_pe813762_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__1160050_pe888728_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__1043678_ph177986_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__0995609_pe821782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__0995619_pe821791_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__0993390_pe820897_s5.jpg?f=s}	31	f
120	2023-06-24 06:12:53.531856+00	2023-06-24 06:12:53.531877+00	20	beige	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0571500_pe666933_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0837298_pe666936_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0837295_pe666935_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0837285_pe666934_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0617563_pe688046_s5.jpg?f=s}	32	f
121	2023-06-24 06:12:53.875826+00	2023-06-24 06:12:53.875848+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0497120_pe628947_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837219_pe629068_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837218_pe628950_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837216_pe628949_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837772_pe629026_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0612906_pe686092_s5.jpg?f=s}	32	f
122	2023-06-24 06:12:54.269222+00	2023-06-24 06:12:54.269244+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0497125_pe628952_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__1184589_ph187101_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0837582_pe629074_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0837579_pe628955_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0837573_pe628954_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0841343_pe629031_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0612906_pe686092_s5.jpg?f=s}	32	f
123	2023-06-24 06:12:54.699268+00	2023-06-24 06:12:54.699297+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0497130_pe628957_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0840367_pe629080_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0840830_pe657554_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0837591_pe628959_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0840815_pe629036_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0612906_pe686092_s5.jpg?f=s}	32	f
124	2023-06-24 06:13:00.082638+00	2023-06-24 06:13:00.082661+00	20	black	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0571496_pe666929_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0837326_pe666932_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0837324_pe666931_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0837321_pe666930_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0617563_pe688046_s5.jpg?f=s}	32	f
125	2023-06-24 06:13:01.839024+00	2023-06-24 06:13:01.839049+00	20	dark gray	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937014_pe793536_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937015_pe793537_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937016_pe793538_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0841254_pe735808_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0612906_pe686092_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937017_pe793539_s5.jpg?f=s}	32	f
126	2023-06-24 06:13:07.401341+00	2023-06-24 06:13:07.401369+00	20	yellow	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936990_pe793502_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936991_pe793517_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936992_pe793504_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936993_pe793505_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0612906_pe686092_s5.jpg?f=s}	32	f
127	2023-06-24 06:13:18.771309+00	2023-06-24 06:13:18.771333+00	20	black	{https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167042_pe891344_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167041_pe891345_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167039_pe891343_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167040_pe891346_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167038_pe891342_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1122304_pe874590_s5.jpg?f=s}	33	f
128	2023-06-24 06:13:19.167538+00	2023-06-24 06:13:19.167569+00	20	dark gray	{https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1167047_pe891349_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1167043_pe891347_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1181975_pe896902_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1167045_pe891351_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1167046_pe891350_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1167044_pe891348_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1122304_pe874590_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1195097_pe902241_s5.jpg?f=s}	33	f
129	2023-06-24 06:13:20.638986+00	2023-06-24 06:13:20.639023+00	20	white	{https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1167052_pe891354_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1167051_pe891355_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1181976_pe896903_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1167049_pe891353_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1167050_pe891356_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1167048_pe891352_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1122304_pe874590_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1197323_pe903477_s5.jpg?f=s}	33	f
130	2023-06-24 06:13:27.286647+00	2023-06-24 06:13:27.28667+00	20	red	{https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1120081_pe873713_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1175276_ph190422_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1212386_ph191900_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1218939_ph190421_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1186082_pe898672_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1190298_ph191902_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1120079_pe873715_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1120078_pe873712_s5.jpg?f=s}	34	f
131	2023-06-24 06:13:28.523013+00	2023-06-24 06:13:28.523036+00	20	dark gray	{https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1119282_pe873451_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1190300_ph191720_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1119279_pe873450_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1186081_pe898673_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1119280_pe873453_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1119281_pe873452_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1169600_pe892511_s5.jpg?f=s}	34	f
132	2023-06-24 06:13:36.84056+00	2023-06-24 06:13:36.840583+00	20	white	{https://www.ikea.com/us/en/images/products/adde-chair-white__0728280_pe736170_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__0872085_pe594884_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__0872092_pe716742_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__1052546_pe846201_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__1052547_pe846202_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__1052545_pe846250_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__0437187_pe590726_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__1052544_pe846199_s5.jpg?f=s}	35	f
133	2023-06-24 06:13:37.250977+00	2023-06-24 06:13:37.251+00	20	black	{https://www.ikea.com/us/en/images/products/adde-chair-black__0728277_pe736167_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__0720893_ph004838_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__0217072_pe360544_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__1052582_pe846237_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__1052583_pe846238_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__0872127_pe594887_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__0871242_pe590544_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__1052581_pe846236_s5.jpg?f=s}	35	f
134	2023-06-24 06:13:50.024634+00	2023-06-24 06:13:50.024656+00	20	white	{https://www.ikea.com/us/en/images/products/teodores-chair-white__0727344_pe735616_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-white__0870801_pe640070_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-white__0871536_pe640577_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-white__0870804_pe640576_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-white__0870808_pe716735_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-white__0949552_pe799848_s5.jpg?f=s}	36	f
135	2023-06-24 06:13:52.052451+00	2023-06-24 06:13:52.052475+00	20	black	{https://www.ikea.com/us/en/images/products/teodores-chair-black__1114240_pe871696_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-black__1114238_pe871698_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-black__1114237_pe871695_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-black__1114239_pe871697_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-black__0949552_pe799848_s5.jpg?f=s}	36	f
136	2023-06-24 06:13:53.498157+00	2023-06-24 06:13:53.498179+00	20	blue	{https://www.ikea.com/us/en/images/products/teodores-chair-blue__1114279_pe871735_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-blue__1114277_pe871737_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-blue__1114276_pe871734_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-blue__1114278_pe871736_s5.jpg?f=s}	36	f
137	2023-06-24 06:13:54.134576+00	2023-06-24 06:13:54.1346+00	20	green	{https://www.ikea.com/us/en/images/products/teodores-chair-green__1114283_pe871739_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-green__1114281_pe871741_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-green__1114280_pe871738_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-green__1114282_pe871740_s5.jpg?f=s}	36	f
138	2023-06-24 06:14:11.5586+00	2023-06-24 06:14:11.558622+00	20	blue	{https://www.ikea.com/us/en/images/products/kyrre-stool-bright-blue__1181813_pe896805_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-bright-blue__1245303_ph193144_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-bright-blue__1181812_pe896806_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-bright-blue__1181811_pe896807_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-bright-blue__1181810_pe896804_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-bright-blue__0948339_pe798962_s5.jpg?f=s}	37	f
139	2023-06-24 06:14:12.433847+00	2023-06-24 06:14:12.433885+00	20	dark gray	{https://www.ikea.com/us/en/images/products/kyrre-stool-birch__0714153_pe729952_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-birch__1076529_ph180023_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-birch__1076258_ph180019_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-birch__1076257_ph180018_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-birch__0933242_ph169316_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-birch__1053340_pe846920_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-birch__1053339_pe846919_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-birch__0948339_pe798962_s5.jpg?f=s}	37	f
140	2023-06-24 06:14:12.956284+00	2023-06-24 06:14:12.956308+00	20	green	{https://www.ikea.com/us/en/images/products/kyrre-stool-dark-green__1016566_pe830489_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-dark-green__1016721_pe830588_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-dark-green__1039307_pe840124_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-dark-green__1016567_pe830492_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-dark-green__0948339_pe798962_s5.jpg?f=s}	37	f
141	2023-06-24 06:14:13.538702+00	2023-06-24 06:14:13.538727+00	20	green	{https://www.ikea.com/us/en/images/products/kyrre-stool-green__1016568_pe830491_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-green__1076260_ph180045_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-green__1016722_pe830587_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-green__1039308_pe840123_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-green__1017985_pe831002_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-green__0948339_pe798962_s5.jpg?f=s}	37	f
142	2023-06-24 06:14:13.966675+00	2023-06-24 06:14:13.966698+00	20	white	{https://www.ikea.com/us/en/images/products/kyrre-stool-white__0913559_pe783644_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-white__0913561_pe783645_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-white__0948339_pe798962_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-white__1053346_pe846926_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-white__1053345_pe846925_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kyrre-stool-white__1053347_pe846921_s5.jpg?f=s}	37	f
143	2023-06-24 06:16:13.87034+00	2023-06-24 06:16:13.870364+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__0644757_pe702939_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1084790_pe859876_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1084796_pe859882_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1051325_pe845148_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1099106_pe865602_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1106842_pe868819_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1117445_pe872744_s5.jpg?f=s}	38	f
144	2023-06-24 06:16:14.273116+00	2023-06-24 06:16:14.27314+00	20	brown	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__0644754_pe702938_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1031126_pe836444_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1102205_pe866558_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1084789_pe859874_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1084795_pe859880_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1084783_pe859868_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1106841_pe868817_s5.jpg?f=s}	38	f
145	2023-06-24 06:16:14.803893+00	2023-06-24 06:16:14.803914+00	20	gray	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-gray-wood-effect__0494558_pe627165_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-gray-wood-effect__1051326_pe845149_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-gray-wood-effect__1113776_pe871541_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-gray-wood-effect__1215327_pe911964_s5.jpg?f=s}	38	f
147	2023-06-24 06:16:15.516864+00	2023-06-24 06:16:15.516889+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__0459250_pe606049_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1051324_pe845147_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1102302_pe866911_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1084797_pe859881_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1084785_pe859869_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1084791_pe859875_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1106843_pe868818_s5.jpg?f=s}	38	f
148	2023-06-24 06:16:30.952919+00	2023-06-24 06:16:30.952944+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__0754627_pe747994_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__0640671_pe699976_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__1102291_pe866900_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__1102290_pe866901_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__1051438_pe845535_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__1106842_pe868819_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__1106846_pe868822_s5.jpg?f=s}	39	f
149	2023-06-24 06:16:31.858272+00	2023-06-24 06:16:31.858295+00	20	brown	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__0754623_pe747987_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__0640672_pe699975_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1052064_pe845908_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1051439_pe845536_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1102465_pe866994_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1092321_pe862819_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1106841_pe868817_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1106845_pe868820_s5.jpg?f=s}	39	f
150	2023-06-24 06:16:33.363845+00	2023-06-24 06:16:33.363878+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-high-gloss-white__0754626_pe747989_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-high-gloss-white__1102468_pe866995_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-high-gloss-white__1102467_pe866996_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-high-gloss-white__1215327_pe911964_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-high-gloss-white__1204109_pe906575_s5.jpg?f=s}	39	f
151	2023-06-24 06:16:33.840651+00	2023-06-24 06:16:33.840677+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__0480295_pe618865_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1102541_pe867020_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1102472_pe866997_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1106843_pe868818_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1106847_pe868821_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1215327_pe911964_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1204109_pe906575_s5.jpg?f=s}	39	f
152	2023-06-24 06:16:39.24402+00	2023-06-24 06:16:39.244043+00	20	dark gray	{https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__0981562_pe815396_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__0981563_pe815398_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__0981564_pe815397_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__0985041_pe816493_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__1017405_pe830805_s5.jpg?f=s}	40	f
153	2023-06-24 06:16:51.740105+00	2023-06-24 06:16:51.740128+00	20	white	{https://www.ikea.com/us/en/images/products/billy-bookcase-white__0644260_pe702536_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-white__0394564_pe561387_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-white__0367673_ph121198_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-white__0546686_pe656298_s5.jpg?f=s}	41	f
154	2023-06-24 06:16:52.342944+00	2023-06-24 06:16:52.342968+00	20	dark gray	{https://www.ikea.com/us/en/images/products/billy-bookcase-birch-veneer__0252339_pe391166_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-birch-veneer__0394546_pe561369_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-birch-veneer__0850386_pe421875_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-birch-veneer__0546686_pe656298_s5.jpg?f=s}	41	f
155	2023-06-24 06:16:53.796709+00	2023-06-24 06:16:53.796733+00	20	brown	{https://www.ikea.com/us/en/images/products/billy-bookcase-black-brown__0644262_pe702535_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-black-brown__0394554_pe561377_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-black-brown__0546686_pe656298_s5.jpg?f=s}	41	f
156	2023-06-24 06:17:05.444197+00	2023-06-24 06:17:05.444223+00	20	white	{https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white__0246565_pe385541_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white__1092772_pe863015_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white__1135810_ph178404_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white__0670330_pe715457_s5.jpg?f=s}	42	f
157	2023-06-24 06:17:07.344816+00	2023-06-24 06:17:07.344859+00	20	brown	{https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-black-brown__0670335_pe715461_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-black-brown__1092776_pe863017_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-black-brown__0670334_pe715460_s5.jpg?f=s}	42	f
159	2023-06-24 06:17:30.045085+00	2023-06-24 06:17:30.045109+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-white-white__1041422_pe841007_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-white-white__1102278_pe866891_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-white-white__1084621_pe859727_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-white-white__1103335_ph181540_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-white-white__1106842_pe868819_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-white-white__1106846_pe868822_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-white-white__1063294_pe851317_s5.jpg?f=s}	43	f
160	2023-06-24 06:17:30.677653+00	2023-06-24 06:17:30.677677+00	20	brown	{https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-black__1041419_pe841018_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-black__1102380_pe866938_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-black__1084619_pe859726_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-black__1106841_pe868817_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-black__1106845_pe868820_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-black__1094438_pe863433_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-black__1063294_pe851317_s5.jpg?f=s}	43	f
161	2023-06-24 06:17:36.003517+00	2023-06-24 06:17:36.003543+00	20	brown	{https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-white__1041432_pe841017_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-white__1102381_pe866939_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-white__1118693_pe873226_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-white__1106841_pe868817_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-white__1106845_pe868820_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-white__1094438_pe863433_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-black-brown-white__1063294_pe851317_s5.jpg?f=s}	43	f
162	2023-06-24 06:17:36.546862+00	2023-06-24 06:17:36.546895+00	20	black	{https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-gray-wood-effect-black__1041429_pe841014_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-gray-wood-effect-black__1102382_pe866940_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-gray-wood-effect-black__1063294_pe851317_s5.jpg?f=s}	43	f
163	2023-06-24 06:17:36.988787+00	2023-06-24 06:17:36.988809+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-gray-wood-effect-white__1041427_pe841012_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-gray-wood-effect-white__1102383_pe866941_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-gray-wood-effect-white__1118132_pe872946_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-gray-wood-effect-white__1063294_pe851317_s5.jpg?f=s}	43	f
164	2023-06-24 06:17:42.857793+00	2023-06-24 06:17:42.857815+00	20	black	{https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-high-gloss-white-black__1041425_pe841010_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-high-gloss-white-black__1102389_pe866942_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-high-gloss-white-black__1106842_pe868819_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-high-gloss-white-black__1106846_pe868822_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-high-gloss-white-black__1063294_pe851317_s5.jpg?f=s}	43	f
165	2023-06-24 06:17:43.270087+00	2023-06-24 06:17:43.270109+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-high-gloss-white-white__1041428_pe841013_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-high-gloss-white-white__1102390_pe866944_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-high-gloss-white-white__1118201_pe872970_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-high-gloss-white-white__1063294_pe851317_s5.jpg?f=s}	43	f
166	2023-06-24 06:17:43.758601+00	2023-06-24 06:17:43.758623+00	20	black	{https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-oak-effect-black__1041446_pe841028_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelving-unit-with-underframe-oak-effect-black__1063297_pe851319_s5.jpg?f=s}	43	f
167	2023-06-24 06:18:31.45577+00	2023-06-24 06:18:31.455793+00	20	dark gray	{https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-antique-stain__0736929_pe740809_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-antique-stain__0208609_pe197452_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-antique-stain__0870916_pe716638_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-antique-stain__0870896_pe594898_s5.jpg?f=s}	44	f
168	2023-06-24 06:18:36.996119+00	2023-06-24 06:18:36.996143+00	20	brown	{https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-black-brown__0574208_pe668154_s5.jpg?f=s}	44	f
169	2023-06-24 06:18:43.046457+00	2023-06-24 06:18:43.046481+00	20	dark gray	{https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0546603_pe656255_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__1015064_ph176248_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0946421_ph173663_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0628543_ph149771_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0809033_ph149979_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0949260_pe799598_s5.jpg?f=s}	45	f
170	2023-06-24 06:18:48.970561+00	2023-06-24 06:18:48.970584+00	20	dark gray	{https://www.ikea.com/us/en/images/products/voxloev-voxloev-table-and-4-chairs-bamboo-bamboo__0926660_pe789444_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/voxloev-voxloev-table-and-4-chairs-bamboo-bamboo__0926661_pe789443_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/voxloev-voxloev-table-and-4-chairs-bamboo-bamboo__0997394_ph176797_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/voxloev-voxloev-table-and-4-chairs-bamboo-bamboo__1002129_ph177193_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/voxloev-voxloev-table-and-4-chairs-bamboo-bamboo__0997059_ph176802_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/voxloev-voxloev-table-and-4-chairs-bamboo-bamboo__0997060_ph176798_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/voxloev-voxloev-table-and-4-chairs-bamboo-bamboo__0977739_pe813788_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/voxloev-voxloev-table-and-4-chairs-bamboo-bamboo__0983262_pe815974_s5.jpg?f=s}	46	f
171	2023-06-24 06:18:53.646951+00	2023-06-24 06:18:53.646987+00	20	black	{https://www.ikea.com/us/en/images/products/melltorp-lidas-table-and-4-chairs-white-white-black-black__1176225_pe894967_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/melltorp-lidas-table-and-4-chairs-white-white-black-black__1176224_pe894968_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/melltorp-lidas-table-and-4-chairs-white-white-black-black__0976365_pe813152_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/melltorp-lidas-table-and-4-chairs-white-white-black-black__1122304_pe874590_s5.jpg?f=s}	47	f
172	2023-06-24 06:18:58.938451+00	2023-06-24 06:18:58.938475+00	20	black	{https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__1097254_pe864851_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__1097281_pe864868_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__0797392_pe766852_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__1053088_pe846684_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__1053089_pe846685_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__0949260_pe799598_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__0947700_pe798621_s5.jpg?f=s}	48	f
173	2023-06-24 06:19:06.844893+00	2023-06-24 06:19:06.844918+00	20	dark gray	{https://www.ikea.com/us/en/images/products/lisabo-lisabo-table-and-4-chairs-ash-veneer-ash__0921113_pe787668_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lisabo-lisabo-table-and-4-chairs-ash-veneer-ash__1221247_pe913674_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lisabo-lisabo-table-and-4-chairs-ash-veneer-ash__1053173_pe846766_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lisabo-lisabo-table-and-4-chairs-ash-veneer-ash__1053171_pe846764_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lisabo-lisabo-table-and-4-chairs-ash-veneer-ash__1053172_pe846765_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lisabo-lisabo-table-and-4-chairs-ash-veneer-ash__0949244_pe799576_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lisabo-lisabo-table-and-4-chairs-ash-veneer-ash__0949242_pe799575_s5.jpg?f=s}	49	f
174	2023-06-24 06:19:07.166481+00	2023-06-24 06:19:07.166504+00	20	black	{https://www.ikea.com/us/en/images/products/lisabo-odger-table-and-4-chairs-black-beige__0737980_pe741295_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lisabo-odger-table-and-4-chairs-black-beige__0871356_pe674065_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lisabo-odger-table-and-4-chairs-black-beige__0871327_pe648694_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lisabo-odger-table-and-4-chairs-black-beige__0871315_pe648693_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lisabo-odger-table-and-4-chairs-black-beige__0949244_pe799576_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lisabo-odger-table-and-4-chairs-black-beige__0948332_pe798956_s5.jpg?f=s}	49	f
24	2023-06-24 05:53:03.320084+00	2023-06-24 07:02:03.062371+00	18	gray	{https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-gray__1041911_pe841191_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-gray__0950149_pe800169_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-gray__0985836_pe816822_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-gray__0985845_pe816830_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-gray__0985826_pe816814_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-gray__0985851_pe816836_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-gray__0515709_pe639965_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-with-chaise-vissle-gray__0950150_pe800164_s5.jpg?f=s}	6	f
\.


--
-- Data for Name: api_voucher; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_voucher (id, created_at, updated_at, is_deleted, discount, from_date, to_date, code, inventory) FROM stdin;
\.


--
-- Data for Name: auth_group; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.auth_group (id, name) FROM stdin;
\.


--
-- Data for Name: auth_group_permissions; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.auth_group_permissions (id, group_id, permission_id) FROM stdin;
\.


--
-- Data for Name: auth_permission; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.auth_permission (id, name, content_type_id, codename) FROM stdin;
1	Can add log entry	1	add_logentry
2	Can change log entry	1	change_logentry
3	Can delete log entry	1	delete_logentry
4	Can view log entry	1	view_logentry
5	Can add permission	2	add_permission
6	Can change permission	2	change_permission
7	Can delete permission	2	delete_permission
8	Can view permission	2	view_permission
9	Can add group	3	add_group
10	Can change group	3	change_group
11	Can delete group	3	delete_group
12	Can view group	3	view_group
13	Can add content type	4	add_contenttype
14	Can change content type	4	change_contenttype
15	Can delete content type	4	delete_contenttype
16	Can view content type	4	view_contenttype
17	Can add session	5	add_session
18	Can change session	5	change_session
19	Can delete session	5	delete_session
20	Can view session	5	view_session
21	Can add user	6	add_user
22	Can change user	6	change_user
23	Can delete user	6	delete_user
24	Can view user	6	view_user
25	Can add category	7	add_category
26	Can change category	7	change_category
27	Can delete category	7	delete_category
28	Can view category	7	view_category
29	Can add product	8	add_product
30	Can change product	8	change_product
31	Can delete product	8	delete_product
32	Can view product	8	view_product
33	Can add order	9	add_order
34	Can change order	9	change_order
35	Can delete order	9	delete_order
36	Can view order	9	view_order
37	Can add variation	10	add_variation
38	Can change variation	10	change_variation
39	Can delete variation	10	delete_variation
40	Can view variation	10	view_variation
41	Can add order detail	11	add_orderdetail
42	Can change order detail	11	change_orderdetail
43	Can delete order detail	11	delete_orderdetail
44	Can view order detail	11	view_orderdetail
45	Can add review	12	add_review
46	Can change review	12	change_review
47	Can delete review	12	delete_review
48	Can view review	12	view_review
49	Can add address	13	add_address
50	Can change address	13	change_address
51	Can delete address	13	delete_address
52	Can view address	13	view_address
53	Can add payment provider	14	add_paymentprovider
54	Can change payment provider	14	change_paymentprovider
55	Can delete payment provider	14	delete_paymentprovider
56	Can view payment provider	14	view_paymentprovider
57	Can add payment	15	add_payment
58	Can change payment	15	change_payment
59	Can delete payment	15	delete_payment
60	Can view payment	15	view_payment
61	Can add cart item	16	add_cartitem
62	Can change cart item	16	change_cartitem
63	Can delete cart item	16	delete_cartitem
64	Can view cart item	16	view_cartitem
65	Can add favorite item	17	add_favoriteitem
66	Can change favorite item	17	change_favoriteitem
67	Can delete favorite item	17	delete_favoriteitem
68	Can view favorite item	17	view_favoriteitem
69	Can add voucher	18	add_voucher
70	Can change voucher	18	change_voucher
71	Can delete voucher	18	delete_voucher
72	Can view voucher	18	view_voucher
73	Can add used voucher	19	add_usedvoucher
74	Can change used voucher	19	change_usedvoucher
75	Can delete used voucher	19	delete_usedvoucher
76	Can view used voucher	19	view_usedvoucher
\.


--
-- Data for Name: authentication_user; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.authentication_user (id, password, last_login, is_superuser, created_at, updated_at, email, is_staff, is_active, date_joined, email_verified, dob, full_name, gender, phone, avatar) FROM stdin;
1	pbkdf2_sha256$600000$VQlXmOJJ2RIocxZXYuHZqK$Ej1cKjbed5VLO62yB0QwYZGG4k9ky7wSFa2HUsanIK8=	\N	f	2023-06-21 03:38:43.862768+00	2023-06-21 03:38:43.862789+00	hdatdragon2@gmail.com	f	t	2023-06-21 03:38:41.363538+00	f	\N	\N	Male	\N	
2	pbkdf2_sha256$600000$RmojYnOZ1n60f1Ogx550gW$Y5O0+obFf+i+qQRxj13jlOeP2zAk7q5jg88hZ4uAfp0=	\N	t	2023-06-21 03:39:32.754448+00	2023-06-21 03:39:32.754476+00	admin@gmail.com	t	t	2023-06-21 03:39:30.420757+00	f	\N	\N	Male	\N	
3	pbkdf2_sha256$600000$UKK0eje8KPIWaoNacrL4As$EcVpvRQvkgEiRKQMYH9574/Flokthq+khvfA6F99FS8=	\N	f	2023-06-21 12:34:03.062687+00	2023-06-21 12:34:03.062709+00	pttu2902@gmail.com	f	t	2023-06-21 12:34:00.412174+00	f	\N	\N	Male	\N	
4	pbkdf2_sha256$600000$9lpeIwXec1D4yHPjnoFgzs$mWeW5B4ZeM5QPus07amrF3+nopTFimOxxxHxRXAj+to=	\N	f	2023-06-23 07:00:15.960432+00	2023-06-23 07:00:15.960453+00	test1@gmail.com	f	t	2023-06-23 07:00:13.206112+00	f	\N	\N	Male	\N	
\.


--
-- Data for Name: authentication_user_groups; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.authentication_user_groups (id, user_id, group_id) FROM stdin;
\.


--
-- Data for Name: authentication_user_user_permissions; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.authentication_user_user_permissions (id, user_id, permission_id) FROM stdin;
\.


--
-- Data for Name: chapter; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.chapter (chapter_id, course_id, numeric_order, name, total_lesson, created_at, updated_at) FROM stdin;
21	1	3	Sub-Ex	0	2023-06-03 15:04:15.435919	2023-06-03 15:04:15.435919
22	2	3	Zontrax	0	2023-06-03 15:04:15.478447	2023-06-03 15:04:15.478447
23	3	3	Transcof	0	2023-06-03 15:04:15.525529	2023-06-03 15:04:15.525529
24	4	3	Lotlux	0	2023-06-03 15:04:15.577259	2023-06-03 15:04:15.577259
25	5	3	Ronstring	0	2023-06-03 15:04:15.690827	2023-06-03 15:04:15.690827
26	6	3	Gembucket	0	2023-06-03 15:04:15.740675	2023-06-03 15:04:15.740675
27	7	3	Viva	0	2023-06-03 15:04:15.782119	2023-06-03 15:04:15.782119
28	8	3	Kanlam	0	2023-06-03 15:04:15.834571	2023-06-03 15:04:15.834571
29	9	3	Zontrax	0	2023-06-03 15:04:15.910171	2023-06-03 15:04:15.910171
30	10	3	Cookley	0	2023-06-03 15:04:15.956613	2023-06-03 15:04:15.956613
31	1	4	Fix San	0	2023-06-03 15:04:15.998248	2023-06-03 15:04:15.998248
32	2	4	Voltsillam	0	2023-06-03 15:04:16.042294	2023-06-03 15:04:16.042294
33	3	4	Bytecard	0	2023-06-03 15:04:16.101382	2023-06-03 15:04:16.101382
34	4	4	Lotlux	0	2023-06-03 15:04:16.155069	2023-06-03 15:04:16.155069
35	5	4	Zontrax	0	2023-06-03 15:04:16.209451	2023-06-03 15:04:16.209451
36	6	4	Temp	0	2023-06-03 15:04:16.252896	2023-06-03 15:04:16.252896
37	7	4	Fix San	0	2023-06-03 15:04:16.30137	2023-06-03 15:04:16.30137
38	8	4	Alphazap	0	2023-06-03 15:04:16.363251	2023-06-03 15:04:16.363251
39	9	4	Zoolab	0	2023-06-03 15:04:16.478138	2023-06-03 15:04:16.478138
40	10	4	Temp	0	2023-06-03 15:04:16.542966	2023-06-03 15:04:16.542966
41	1	5	Tresom	0	2023-06-03 15:04:16.775272	2023-06-03 15:04:16.775272
42	2	5	Bitwolf	0	2023-06-03 15:04:16.817172	2023-06-03 15:04:16.817172
43	3	5	Treeflex	0	2023-06-03 15:04:16.863004	2023-06-03 15:04:16.863004
44	4	5	Zamit	0	2023-06-03 15:04:16.916711	2023-06-03 15:04:16.916711
45	5	5	Holdlamis	0	2023-06-03 15:04:16.966998	2023-06-03 15:04:16.966998
46	6	5	Span	0	2023-06-03 15:04:17.012841	2023-06-03 15:04:17.012841
47	7	5	Cookley	0	2023-06-03 15:04:17.061427	2023-06-03 15:04:17.061427
48	8	5	Solarbreeze	0	2023-06-03 15:04:17.10446	2023-06-03 15:04:17.10446
49	9	5	Wrapsafe	0	2023-06-03 15:04:17.153474	2023-06-03 15:04:17.153474
50	10	5	Mat Lam Tam	0	2023-06-03 15:04:17.2212	2023-06-03 15:04:17.2212
51	1	6	Greenlam	0	2023-06-03 15:04:17.263545	2023-06-03 15:04:17.263545
52	2	6	Andalax	0	2023-06-03 15:04:17.310496	2023-06-03 15:04:17.310496
53	3	6	Aerified	0	2023-06-03 15:04:17.358211	2023-06-03 15:04:17.358211
54	4	6	Flowdesk	0	2023-06-03 15:04:17.404114	2023-06-03 15:04:17.404114
55	5	6	Tampflex	0	2023-06-03 15:04:17.44878	2023-06-03 15:04:17.44878
56	6	6	Sonair	0	2023-06-03 15:04:17.492333	2023-06-03 15:04:17.492333
57	7	6	Alpha	0	2023-06-03 15:04:17.540004	2023-06-03 15:04:17.540004
58	8	6	It	0	2023-06-03 15:04:17.591386	2023-06-03 15:04:17.591386
59	9	6	Zontrax	0	2023-06-03 15:04:17.637436	2023-06-03 15:04:17.637436
60	10	6	Zathin	0	2023-06-03 15:04:17.682569	2023-06-03 15:04:17.682569
61	1	7	Tresom	0	2023-06-03 15:04:18.177849	2023-06-03 15:04:18.177849
62	2	7	Overhold	0	2023-06-03 15:04:18.681057	2023-06-03 15:04:18.681057
63	3	7	Flexidy	0	2023-06-03 15:04:18.726216	2023-06-03 15:04:18.726216
64	4	7	Alpha	0	2023-06-03 15:04:18.770099	2023-06-03 15:04:18.770099
65	5	7	Biodex	0	2023-06-03 15:04:18.888872	2023-06-03 15:04:18.888872
66	6	7	Kanlam	0	2023-06-03 15:04:18.934231	2023-06-03 15:04:18.934231
67	7	7	Wrapsafe	0	2023-06-03 15:04:18.993683	2023-06-03 15:04:18.993683
68	8	7	Cardify	0	2023-06-03 15:04:19.042948	2023-06-03 15:04:19.042948
69	9	7	Viva	0	2023-06-03 15:04:19.091791	2023-06-03 15:04:19.091791
70	10	7	Namfix	0	2023-06-03 15:04:19.142961	2023-06-03 15:04:19.142961
71	1	8	Span	0	2023-06-03 15:04:19.213788	2023-06-03 15:04:19.213788
72	2	8	Bamity	0	2023-06-03 15:04:19.258269	2023-06-03 15:04:19.258269
73	3	8	Bitwolf	0	2023-06-03 15:04:19.30873	2023-06-03 15:04:19.30873
74	4	8	Fintone	0	2023-06-03 15:04:19.351295	2023-06-03 15:04:19.351295
75	5	8	Latlux	0	2023-06-03 15:04:19.400883	2023-06-03 15:04:19.400883
76	6	8	Transcof	0	2023-06-03 15:04:19.453734	2023-06-03 15:04:19.453734
77	7	8	Job	0	2023-06-03 15:04:19.502984	2023-06-03 15:04:19.502984
78	8	8	Subin	0	2023-06-03 15:04:19.553031	2023-06-03 15:04:19.553031
79	9	8	Konklux	0	2023-06-03 15:04:19.615069	2023-06-03 15:04:19.615069
80	10	8	Andalax	0	2023-06-03 15:04:19.659152	2023-06-03 15:04:19.659152
81	1	9	Greenlam	0	2023-06-03 15:04:19.706715	2023-06-03 15:04:19.706715
82	2	9	Sonair	0	2023-06-03 15:04:19.773378	2023-06-03 15:04:19.773378
83	3	9	Matsoft	0	2023-06-03 15:04:19.828404	2023-06-03 15:04:19.828404
84	4	9	Stronghold	0	2023-06-03 15:04:19.871948	2023-06-03 15:04:19.871948
85	5	9	Sub-Ex	0	2023-06-03 15:04:19.91817	2023-06-03 15:04:19.91817
86	6	9	Vagram	0	2023-06-03 15:04:19.962981	2023-06-03 15:04:19.962981
87	7	9	Cardguard	0	2023-06-03 15:04:20.009922	2023-06-03 15:04:20.009922
88	8	9	Cardguard	0	2023-06-03 15:04:20.063491	2023-06-03 15:04:20.063491
89	9	9	Pannier	0	2023-06-03 15:04:20.106005	2023-06-03 15:04:20.106005
90	10	9	Zontrax	0	2023-06-03 15:04:20.150441	2023-06-03 15:04:20.150441
91	1	10	Fix San	0	2023-06-03 15:04:20.22767	2023-06-03 15:04:20.22767
92	2	10	Aerified	0	2023-06-03 15:04:20.279085	2023-06-03 15:04:20.279085
93	3	10	Trippledex	0	2023-06-03 15:04:20.322815	2023-06-03 15:04:20.322815
94	4	10	Wrapsafe	0	2023-06-03 15:04:20.471841	2023-06-03 15:04:20.471841
95	5	10	Fix San	0	2023-06-03 15:04:20.526592	2023-06-03 15:04:20.526592
96	6	10	Zontrax	0	2023-06-03 15:04:20.611234	2023-06-03 15:04:20.611234
97	7	10	Temp	0	2023-06-03 15:04:20.661723	2023-06-03 15:04:20.661723
98	8	10	Zaam-Dox	0	2023-06-03 15:04:20.734333	2023-06-03 15:04:20.734333
99	9	10	Veribet	0	2023-06-03 15:04:20.783019	2023-06-03 15:04:20.783019
100	10	10	It	0	2023-06-03 15:04:20.835289	2023-06-03 15:04:20.835289
6	6	1	Sonsing	15	2023-06-03 15:04:14.594714	2023-06-03 15:04:52.47707
12	2	2	Zaam-Dox	15	2023-06-03 15:04:14.900768	2023-06-03 15:04:52.931247
13	3	2	Andalax	15	2023-06-03 15:04:14.952109	2023-06-03 15:04:52.975419
14	4	2	Stim	15	2023-06-03 15:04:14.996794	2023-06-03 15:04:53.025894
15	5	2	Cookley	15	2023-06-03 15:04:15.03927	2023-06-03 15:04:53.187157
18	8	2	Trippledex	15	2023-06-03 15:04:15.228799	2023-06-03 15:04:53.483266
19	9	2	Overhold	15	2023-06-03 15:04:15.273208	2023-06-03 15:04:53.538957
20	10	2	Solarbreeze	15	2023-06-03 15:04:15.351677	2023-06-03 15:04:53.581196
1	1	1	Fintone	15	2023-06-03 15:04:14.351162	2023-06-03 15:04:51.991525
2	2	1	Greenlam	15	2023-06-03 15:04:14.403994	2023-06-03 15:04:52.050372
3	3	1	Sonair	15	2023-06-03 15:04:14.4522	2023-06-03 15:04:52.236456
7	7	1	Holdlamis	15	2023-06-03 15:04:14.640789	2023-06-03 15:04:52.52193
8	8	1	Ventosanzap	15	2023-06-03 15:04:14.690306	2023-06-03 15:04:52.634601
9	9	1	Job	15	2023-06-03 15:04:14.731892	2023-06-03 15:04:52.734321
4	4	1	Holdlamis	15	2023-06-03 15:04:14.500288	2023-06-03 15:04:52.332628
5	5	1	Redhold	15	2023-06-03 15:04:14.545932	2023-06-03 15:04:52.43497
10	10	1	Tresom	15	2023-06-03 15:04:14.7904	2023-06-03 15:04:52.78771
11	1	2	Fixflex	15	2023-06-03 15:04:14.843742	2023-06-03 15:04:52.886912
16	6	2	Duobam	15	2023-06-03 15:04:15.084215	2023-06-03 15:04:53.334319
17	7	2	Gembucket	15	2023-06-03 15:04:15.135182	2023-06-03 15:04:53.380648
\.


--
-- Data for Name: choice; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.choice (choice_id, question_id, order_choice, name, key, created_at, updated_at) FROM stdin;
1	1	1		f	2023-06-03 23:24:43.631129	2023-06-03 23:24:43.631129
2	1	2		t	2023-06-03 23:24:43.67934	2023-06-03 23:24:43.67934
3	1	3		f	2023-06-03 23:24:43.741828	2023-06-03 23:24:43.741828
4	1	4		f	2023-06-03 23:24:43.786158	2023-06-03 23:24:43.786158
5	2	1		f	2023-06-03 23:24:43.828661	2023-06-03 23:24:43.828661
6	2	2		f	2023-06-03 23:24:43.872349	2023-06-03 23:24:43.872349
7	2	3		t	2023-06-03 23:24:43.915086	2023-06-03 23:24:43.915086
8	2	4		f	2023-06-03 23:24:43.957619	2023-06-03 23:24:43.957619
9	3	1		f	2023-06-03 23:24:44.000162	2023-06-03 23:24:44.000162
10	3	2		t	2023-06-03 23:24:44.042542	2023-06-03 23:24:44.042542
11	3	3		f	2023-06-03 23:24:44.086617	2023-06-03 23:24:44.086617
12	3	4		f	2023-06-03 23:24:44.132897	2023-06-03 23:24:44.132897
13	4	1		t	2023-06-03 23:24:44.232332	2023-06-03 23:24:44.232332
14	4	2		f	2023-06-03 23:24:44.280301	2023-06-03 23:24:44.280301
15	4	3		f	2023-06-03 23:24:44.330526	2023-06-03 23:24:44.330526
16	4	4		f	2023-06-03 23:24:44.373047	2023-06-03 23:24:44.373047
17	5	1		f	2023-06-03 23:24:44.415753	2023-06-03 23:24:44.415753
18	5	2		f	2023-06-03 23:24:44.458075	2023-06-03 23:24:44.458075
19	5	3		f	2023-06-03 23:24:44.500874	2023-06-03 23:24:44.500874
20	5	4		t	2023-06-03 23:24:44.546952	2023-06-03 23:24:44.546952
21	6	1		f	2023-06-03 23:24:44.592536	2023-06-03 23:24:44.592536
22	6	2		f	2023-06-03 23:24:44.729831	2023-06-03 23:24:44.729831
23	6	3		t	2023-06-03 23:24:44.777513	2023-06-03 23:24:44.777513
24	6	4		f	2023-06-03 23:24:44.822189	2023-06-03 23:24:44.822189
25	7	1		f	2023-06-03 23:24:44.864546	2023-06-03 23:24:44.864546
26	7	2		t	2023-06-03 23:24:44.932085	2023-06-03 23:24:44.932085
27	7	3		f	2023-06-03 23:24:45.004085	2023-06-03 23:24:45.004085
28	8	1		t	2023-06-03 23:24:45.046472	2023-06-03 23:24:45.046472
29	8	2		f	2023-06-03 23:24:45.089151	2023-06-03 23:24:45.089151
30	8	3		f	2023-06-03 23:24:45.154176	2023-06-03 23:24:45.154176
31	9	1		f	2023-06-03 23:24:45.20148	2023-06-03 23:24:45.20148
32	9	2		f	2023-06-03 23:24:45.24483	2023-06-03 23:24:45.24483
33	9	3		t	2023-06-03 23:24:45.287534	2023-06-03 23:24:45.287534
34	10	1		f	2023-06-03 23:24:45.330339	2023-06-03 23:24:45.330339
35	10	2		f	2023-06-03 23:24:45.374113	2023-06-03 23:24:45.374113
36	10	3		t	2023-06-03 23:24:45.416798	2023-06-03 23:24:45.416798
37	11	1		t	2023-06-03 23:24:45.459322	2023-06-03 23:24:45.459322
38	11	2		f	2023-06-03 23:24:45.502184	2023-06-03 23:24:45.502184
39	11	3		f	2023-06-03 23:24:45.5448	2023-06-03 23:24:45.5448
40	12	1		f	2023-06-03 23:24:45.587148	2023-06-03 23:24:45.587148
41	12	2		t	2023-06-03 23:24:45.665518	2023-06-03 23:24:45.665518
42	12	3		f	2023-06-03 23:24:45.747168	2023-06-03 23:24:45.747168
43	13	1		f	2023-06-03 23:24:45.789902	2023-06-03 23:24:45.789902
44	13	2		f	2023-06-03 23:24:45.836275	2023-06-03 23:24:45.836275
45	13	3		t	2023-06-03 23:24:45.880887	2023-06-03 23:24:45.880887
46	14	1		t	2023-06-03 23:24:45.923526	2023-06-03 23:24:45.923526
47	14	2		f	2023-06-03 23:24:45.966361	2023-06-03 23:24:45.966361
48	14	3		f	2023-06-03 23:24:46.008647	2023-06-03 23:24:46.008647
49	15	1		f	2023-06-03 23:24:46.055029	2023-06-03 23:24:46.055029
50	15	2		t	2023-06-03 23:24:46.115692	2023-06-03 23:24:46.115692
51	15	3		f	2023-06-03 23:24:46.182111	2023-06-03 23:24:46.182111
52	16	1		t	2023-06-03 23:24:46.226137	2023-06-03 23:24:46.226137
53	16	2		f	2023-06-03 23:24:46.268752	2023-06-03 23:24:46.268752
54	16	3		f	2023-06-03 23:24:46.31133	2023-06-03 23:24:46.31133
55	17	1		f	2023-06-03 23:24:46.353617	2023-06-03 23:24:46.353617
56	17	2		f	2023-06-03 23:24:46.39763	2023-06-03 23:24:46.39763
57	17	3		t	2023-06-03 23:24:46.441344	2023-06-03 23:24:46.441344
58	18	1		f	2023-06-03 23:24:46.525534	2023-06-03 23:24:46.525534
59	18	2		t	2023-06-03 23:24:46.597541	2023-06-03 23:24:46.597541
60	18	3		f	2023-06-03 23:24:46.642527	2023-06-03 23:24:46.642527
61	19	1		f	2023-06-03 23:24:46.685201	2023-06-03 23:24:46.685201
62	19	2		f	2023-06-03 23:24:46.727751	2023-06-03 23:24:46.727751
63	19	3		t	2023-06-03 23:24:46.770325	2023-06-03 23:24:46.770325
64	20	1		t	2023-06-03 23:24:46.813128	2023-06-03 23:24:46.813128
65	20	2		f	2023-06-03 23:24:46.873543	2023-06-03 23:24:46.873543
66	20	3		f	2023-06-03 23:24:47.022524	2023-06-03 23:24:47.022524
67	21	1		f	2023-06-03 23:24:47.064735	2023-06-03 23:24:47.064735
68	21	2		f	2023-06-03 23:24:47.107445	2023-06-03 23:24:47.107445
69	21	3		t	2023-06-03 23:24:47.150969	2023-06-03 23:24:47.150969
70	22	1		f	2023-06-03 23:24:47.194016	2023-06-03 23:24:47.194016
71	22	2		t	2023-06-03 23:24:47.242014	2023-06-03 23:24:47.242014
72	22	3		f	2023-06-03 23:24:47.308764	2023-06-03 23:24:47.308764
73	23	1		t	2023-06-03 23:24:47.37042	2023-06-03 23:24:47.37042
74	23	2		f	2023-06-03 23:24:47.413626	2023-06-03 23:24:47.413626
75	23	3		f	2023-06-03 23:24:47.459184	2023-06-03 23:24:47.459184
76	24	1		f	2023-06-03 23:24:47.501782	2023-06-03 23:24:47.501782
77	24	2		t	2023-06-03 23:24:47.544095	2023-06-03 23:24:47.544095
78	24	3		f	2023-06-03 23:24:47.588297	2023-06-03 23:24:47.588297
79	25	1		f	2023-06-03 23:24:47.638953	2023-06-03 23:24:47.638953
80	25	2		f	2023-06-03 23:24:47.684313	2023-06-03 23:24:47.684313
81	25	3		t	2023-06-03 23:24:47.726861	2023-06-03 23:24:47.726861
82	26	1		f	2023-06-03 23:24:47.775207	2023-06-03 23:24:47.775207
83	26	2		f	2023-06-03 23:24:47.866939	2023-06-03 23:24:47.866939
84	26	3		t	2023-06-03 23:24:47.909372	2023-06-03 23:24:47.909372
85	27	1		t	2023-06-03 23:24:47.955072	2023-06-03 23:24:47.955072
86	27	2		f	2023-06-03 23:24:48.002735	2023-06-03 23:24:48.002735
87	27	3		f	2023-06-03 23:24:48.046032	2023-06-03 23:24:48.046032
88	28	1		t	2023-06-03 23:24:48.092642	2023-06-03 23:24:48.092642
89	28	2		f	2023-06-03 23:24:48.134976	2023-06-03 23:24:48.134976
90	28	3		f	2023-06-03 23:24:48.196539	2023-06-03 23:24:48.196539
91	29	1		t	2023-06-03 23:24:48.239521	2023-06-03 23:24:48.239521
92	29	2		f	2023-06-03 23:24:48.284471	2023-06-03 23:24:48.284471
93	29	3		f	2023-06-03 23:24:48.327114	2023-06-03 23:24:48.327114
94	30	1		f	2023-06-03 23:24:48.369625	2023-06-03 23:24:48.369625
95	30	2		t	2023-06-03 23:24:48.412124	2023-06-03 23:24:48.412124
96	30	3		f	2023-06-03 23:24:48.48228	2023-06-03 23:24:48.48228
97	31	1		f	2023-06-03 23:24:48.53064	2023-06-03 23:24:48.53064
98	31	2		f	2023-06-03 23:24:48.573837	2023-06-03 23:24:48.573837
99	31	3		t	2023-06-03 23:24:48.620919	2023-06-03 23:24:48.620919
100	32	1	A move to a new a city	f	2023-06-03 23:24:48.687001	2023-06-03 23:24:48.687001
101	32	2	A business trip	f	2023-06-03 23:24:48.732318	2023-06-03 23:24:48.732318
102	32	3	A building tour	f	2023-06-03 23:24:48.774637	2023-06-03 23:24:48.774637
103	32	4	A meeting with visiting colleagues	t	2023-06-03 23:24:48.819891	2023-06-03 23:24:48.819891
104	33	1	An accountant	f	2023-06-03 23:24:48.871443	2023-06-03 23:24:48.871443
105	33	2	An administrative assistant	t	2023-06-03 23:24:48.918966	2023-06-03 23:24:48.918966
106	33	3	A marketing director	f	2023-06-03 23:24:48.962433	2023-06-03 23:24:48.962433
107	33	4	A company president	f	2023-06-03 23:24:49.006221	2023-06-03 23:24:49.006221
108	34	1	A building map	f	2023-06-03 23:24:49.050971	2023-06-03 23:24:49.050971
109	34	2	A room key	t	2023-06-03 23:24:49.093987	2023-06-03 23:24:49.093987
110	34	3	An ID card	f	2023-06-03 23:24:49.146942	2023-06-03 23:24:49.146942
111	34	4	A parking pass	f	2023-06-03 23:24:49.193443	2023-06-03 23:24:49.193443
112	35	1	Writing a budget	t	2023-06-03 23:24:49.27701	2023-06-03 23:24:49.27701
113	35	2	Reviewing job applications	f	2023-06-03 23:24:49.319683	2023-06-03 23:24:49.319683
114	35	3	Organizing a company newsletter	f	2023-06-03 23:24:49.389259	2023-06-03 23:24:49.389259
115	35	4	Updating an employee handbook	f	2023-06-03 23:24:49.432048	2023-06-03 23:24:49.432048
116	36	1	Organize a trade show	f	2023-06-03 23:24:49.476729	2023-06-03 23:24:49.476729
117	36	2	Open a new store	f	2023-06-03 23:24:49.520866	2023-06-03 23:24:49.520866
118	36	3	Redesign a product catalog	f	2023-06-03 23:24:49.565041	2023-06-03 23:24:49.565041
119	36	4	Hire some team members	t	2023-06-03 23:24:49.610952	2023-06-03 23:24:49.610952
120	37	1	Order some business cards	f	2023-06-03 23:24:49.655131	2023-06-03 23:24:49.655131
121	37	2	Write a press release	f	2023-06-03 23:24:49.728665	2023-06-03 23:24:49.728665
122	37	3	Provide some additional details	t	2023-06-03 23:24:49.772525	2023-06-03 23:24:49.772525
123	37	4	Set up a meeting time	f	2023-06-03 23:24:49.816102	2023-06-03 23:24:49.816102
124	38	1	A job interview	t	2023-06-03 23:24:49.85884	2023-06-03 23:24:49.85884
125	38	2	A fashion show	f	2023-06-03 23:24:49.911443	2023-06-03 23:24:49.911443
126	38	3	A family celebration	f	2023-06-03 23:24:49.986961	2023-06-03 23:24:49.986961
127	38	4	A television appearance	f	2023-06-03 23:24:50.054697	2023-06-03 23:24:50.054697
128	39	1	The fabric	f	2023-06-03 23:24:50.099863	2023-06-03 23:24:50.099863
129	39	2	The price	f	2023-06-03 23:24:50.143035	2023-06-03 23:24:50.143035
130	39	3	The style	f	2023-06-03 23:24:50.189314	2023-06-03 23:24:50.189314
131	39	4	The color	t	2023-06-03 23:24:50.233372	2023-06-03 23:24:50.233372
132	40	1	Some accessories	f	2023-06-03 23:24:50.279051	2023-06-03 23:24:50.279051
133	40	2	Alterations	t	2023-06-03 23:24:50.328954	2023-06-03 23:24:50.328954
134	40	3	Sales tax	f	2023-06-03 23:24:50.37203	2023-06-03 23:24:50.37203
135	40	4	Delivery	f	2023-06-03 23:24:50.41479	2023-06-03 23:24:50.41479
136	41	1	A legal consulting firm	f	2023-06-03 23:24:50.457854	2023-06-03 23:24:50.457854
137	41	2	An architecture firm	f	2023-06-03 23:24:50.505255	2023-06-03 23:24:50.505255
138	41	3	A film production company	t	2023-06-03 23:24:50.595684	2023-06-03 23:24:50.595684
139	41	4	A book publishing company	f	2023-06-03 23:24:50.735181	2023-06-03 23:24:50.735181
140	42	1	The length of a project	t	2023-06-03 23:24:50.799204	2023-06-03 23:24:50.799204
141	42	2	The cost of an order	f	2023-06-03 23:24:50.85077	2023-06-03 23:24:50.85077
142	42	3	The opinion of the public	f	2023-06-03 23:24:50.899042	2023-06-03 23:24:50.899042
143	42	4	The skills of some workers	f	2023-06-03 23:24:50.945356	2023-06-03 23:24:50.945356
144	43	1	Submit an application	f	2023-06-03 23:24:51.001094	2023-06-03 23:24:51.001094
145	43	2	Speak at a meeting	t	2023-06-03 23:24:51.065626	2023-06-03 23:24:51.065626
146	43	3	Review some books	f	2023-06-03 23:24:51.134336	2023-06-03 23:24:51.134336
147	43	4	Measure a space	f	2023-06-03 23:24:51.234346	2023-06-03 23:24:51.234346
148	44	1	A store manager	f	2023-06-03 23:24:51.334442	2023-06-03 23:24:51.334442
149	44	2	A construction worker	f	2023-06-03 23:24:51.434414	2023-06-03 23:24:51.434414
150	44	3	A journalist	f	2023-06-03 23:24:51.477066	2023-06-03 23:24:51.477066
151	44	4	An artist	t	2023-06-03 23:24:51.519809	2023-06-03 23:24:51.519809
152	45	1	Some walls are being painted.	f	2023-06-03 23:24:51.634335	2023-06-03 23:24:51.634335
153	45	2	Some floors are being replaced.	t	2023-06-03 23:24:51.677647	2023-06-03 23:24:51.677647
154	45	3	Some windows are being installed.	f	2023-06-03 23:24:51.720448	2023-06-03 23:24:51.720448
155	45	4	Some light fixtures are being repaired.	f	2023-06-03 23:24:51.834331	2023-06-03 23:24:51.834331
156	46	1	Visit a gift shop	t	2023-06-03 23:24:51.8771	2023-06-03 23:24:51.8771
157	46	2	Send a package	f	2023-06-03 23:24:51.919716	2023-06-03 23:24:51.919716
158	46	3	Wait for a bus	f	2023-06-03 23:24:51.962205	2023-06-03 23:24:51.962205
159	46	4	Take a photograph	f	2023-06-03 23:24:52.100873	2023-06-03 23:24:52.100873
160	47	1	Electronics	f	2023-06-03 23:24:52.275272	2023-06-03 23:24:52.275272
161	47	2	Clothing	f	2023-06-03 23:24:52.337352	2023-06-03 23:24:52.337352
162	47	3	Food	f	2023-06-03 23:24:52.434325	2023-06-03 23:24:52.434325
163	47	4	Automobiles	t	2023-06-03 23:24:52.483275	2023-06-03 23:24:52.483275
164	48	1	Some software is expensive.	f	2023-06-03 23:24:52.527265	2023-06-03 23:24:52.527265
165	48	2	A color is very bright.	f	2023-06-03 23:24:52.570224	2023-06-03 23:24:52.570224
166	48	3	The man has completed a report.	t	2023-06-03 23:24:52.676877	2023-06-03 23:24:52.676877
167	48	4	The man bought a new car.	f	2023-06-03 23:24:52.720451	2023-06-03 23:24:52.720451
168	49	1	To request assistance reviewing a document	f	2023-06-03 23:24:52.765146	2023-06-03 23:24:52.765146
169	49	2	To recommend using a document as a reference	t	2023-06-03 23:24:52.906107	2023-06-03 23:24:52.906107
170	49	3	To report that a task has been completed	f	2023-06-03 23:24:52.949354	2023-06-03 23:24:52.949354
171	49	4	To indicate that a file is in the wrong location	f	2023-06-03 23:24:52.995629	2023-06-03 23:24:52.995629
172	50	1	An executive will visit.	f	2023-06-03 23:24:53.03914	2023-06-03 23:24:53.03914
173	50	2	An employee will retire.	t	2023-06-03 23:24:53.134318	2023-06-03 23:24:53.134318
174	50	3	A product will be released.	f	2023-06-03 23:24:53.234315	2023-06-03 23:24:53.234315
175	50	4	A study will be completed.	f	2023-06-03 23:24:53.277061	2023-06-03 23:24:53.277061
176	51	1	Where he would be working	f	2023-06-03 23:24:53.319635	2023-06-03 23:24:53.319635
177	51	2	When he would be starting a job	t	2023-06-03 23:24:53.362359	2023-06-03 23:24:53.362359
178	51	3	How to get to an office building	f	2023-06-03 23:24:53.40497	2023-06-03 23:24:53.40497
179	51	4	Why an event time has changed	f	2023-06-03 23:24:53.449603	2023-06-03 23:24:53.449603
180	52	1	A work vehicle	f	2023-06-03 23:24:53.547004	2023-06-03 23:24:53.547004
181	52	2	A private office	f	2023-06-03 23:24:53.589466	2023-06-03 23:24:53.589466
182	52	3	Moving expenses	t	2023-06-03 23:24:53.63209	2023-06-03 23:24:53.63209
183	52	4	Visitors` meals	f	2023-06-03 23:24:53.674469	2023-06-03 23:24:53.674469
184	53	1	Manufacturing	f	2023-06-03 23:24:53.716619	2023-06-03 23:24:53.716619
185	53	2	Agriculture	f	2023-06-03 23:24:53.762096	2023-06-03 23:24:53.762096
186	53	3	Transportation	f	2023-06-03 23:24:53.805426	2023-06-03 23:24:53.805426
187	53	4	Construction	t	2023-06-03 23:24:53.848922	2023-06-03 23:24:53.848922
188	54	1	Increase tourism	f	2023-06-03 23:24:53.89315	2023-06-03 23:24:53.89315
189	54	2	Generate electricity	t	2023-06-03 23:24:53.938552	2023-06-03 23:24:53.938552
190	54	3	Preserve natural resources	f	2023-06-03 23:24:53.986468	2023-06-03 23:24:53.986468
191	54	4	Improve property values	f	2023-06-03 23:24:54.029968	2023-06-03 23:24:54.029968
192	55	1	Permits need to be approved.	t	2023-06-03 23:24:54.07276	2023-06-03 23:24:54.07276
193	55	2	Employees need to be trained.	f	2023-06-03 23:24:54.165714	2023-06-03 23:24:54.165714
194	55	3	Materials need to be ordered.	f	2023-06-03 23:24:54.236874	2023-06-03 23:24:54.236874
195	55	4	Inspections need to be made.	f	2023-06-03 23:24:54.280456	2023-06-03 23:24:54.280456
196	56	1	She has time to help.	t	2023-06-03 23:24:54.34173	2023-06-03 23:24:54.34173
197	56	2	She plans to leave work early.	f	2023-06-03 23:24:54.384031	2023-06-03 23:24:54.384031
198	56	3	Her computer is not working.	f	2023-06-03 23:24:54.449589	2023-06-03 23:24:54.449589
199	56	4	She has not received an assignment.	f	2023-06-03 23:24:54.498184	2023-06-03 23:24:54.498184
200	57	1	It needs to be refrigerated.	f	2023-06-03 23:24:54.54079	2023-06-03 23:24:54.54079
201	57	2	It has expired.	f	2023-06-03 23:24:54.584735	2023-06-03 23:24:54.584735
202	57	3	The dosage has changed.	f	2023-06-03 23:24:54.627225	2023-06-03 23:24:54.627225
203	57	4	The supply is limited.	t	2023-06-03 23:24:54.669803	2023-06-03 23:24:54.669803
204	58	1	Installing some shelves	f	2023-06-03 23:24:54.733532	2023-06-03 23:24:54.733532
205	58	2	Confirming with a doctor	f	2023-06-03 23:24:54.823454	2023-06-03 23:24:54.823454
206	58	3	Increasing an order amount	t	2023-06-03 23:24:54.866067	2023-06-03 23:24:54.866067
207	58	4	Recommending a different medication	f	2023-06-03 23:24:54.908921	2023-06-03 23:24:54.908921
208	59	1	A travel agent	f	2023-06-03 23:24:54.951886	2023-06-03 23:24:54.951886
209	59	2	A bank teller	f	2023-06-03 23:24:54.994447	2023-06-03 23:24:54.994447
210	59	3	A lawyer	t	2023-06-03 23:24:55.037211	2023-06-03 23:24:55.037211
211	59	4	A mail-room worker	f	2023-06-03 23:24:55.079787	2023-06-03 23:24:55.079787
212	60	1	A user agreement	t	2023-06-03 23:24:55.122361	2023-06-03 23:24:55.122361
213	60	2	An employment contract	f	2023-06-03 23:24:55.165483	2023-06-03 23:24:55.165483
214	60	3	A list of travel expenses	f	2023-06-03 23:24:55.208106	2023-06-03 23:24:55.208106
215	60	4	An insurance certificate	f	2023-06-03 23:24:55.251361	2023-06-03 23:24:55.251361
216	61	1	To be included in a personnel file a	f	2023-06-03 23:24:55.294486	2023-06-03 23:24:55.294486
217	61	2	To use in a merger negotiation	f	2023-06-03 23:24:55.337563	2023-06-03 23:24:55.337563
218	61	3	To meet a production deadline	f	2023-06-03 23:24:55.416738	2023-06-03 23:24:55.416738
219	61	4	To avoid paying a fine	t	2023-06-03 23:24:55.473318	2023-06-03 23:24:55.473318
220	62	1	$4,456	f	2023-06-03 23:24:55.516289	2023-06-03 23:24:55.516289
221	62	2	$1,300	f	2023-06-03 23:24:55.558688	2023-06-03 23:24:55.558688
222	62	3	$10,200	t	2023-06-03 23:24:55.606081	2023-06-03 23:24:55.606081
223	62	4	$400	f	2023-06-03 23:24:55.650563	2023-06-03 23:24:55.650563
224	63	1	Business hours have changed.	f	2023-06-03 23:24:55.695122	2023-06-03 23:24:55.695122
225	63	2	A price was wrong.	f	2023-06-03 23:24:55.742961	2023-06-03 23:24:55.742961
226	63	3	Some staff arrived late.	t	2023-06-03 23:24:55.789564	2023-06-03 23:24:55.789564
227	63	4	A request could not be fulfilled.	f	2023-06-03 23:24:55.838986	2023-06-03 23:24:55.838986
228	64	1	It has a nice view.	t	2023-06-03 23:24:55.884893	2023-06-03 23:24:55.884893
229	64	2	It is conveniently located.	f	2023-06-03 23:24:55.956439	2023-06-03 23:24:55.956439
230	64	3	It is tastefully decorated.	f	2023-06-03 23:24:56.027692	2023-06-03 23:24:56.027692
231	64	4	It can host large events.	f	2023-06-03 23:24:56.075252	2023-06-03 23:24:56.075252
232	65	1	A popular band is coming to town.	f	2023-06-03 23:24:56.118994	2023-06-03 23:24:56.118994
233	65	2	The woman plays a musical instrument.	f	2023-06-03 23:24:56.175721	2023-06-03 23:24:56.175721
234	65	3	The woman was able to get concert tickets.	t	2023-06-03 23:24:56.223682	2023-06-03 23:24:56.223682
235	65	4	Some musicians a scheduled a second concert.	f	2023-06-03 23:24:56.26695	2023-06-03 23:24:56.26695
236	66	1	Section 1	f	2023-06-03 23:24:56.311019	2023-06-03 23:24:56.311019
237	66	2	Section 2	f	2023-06-03 23:24:56.363215	2023-06-03 23:24:56.363215
238	66	3	Section 3	t	2023-06-03 23:24:56.411425	2023-06-03 23:24:56.411425
239	66	4	Section 4	f	2023-06-03 23:24:56.45531	2023-06-03 23:24:56.45531
240	67	1	Practicing with her band	f	2023-06-03 23:24:56.502429	2023-06-03 23:24:56.502429
241	67	2	Entering a radio contest	f	2023-06-03 23:24:56.55208	2023-06-03 23:24:56.55208
242	67	3	Moving to Boston	f	2023-06-03 23:24:56.669633	2023-06-03 23:24:56.669633
243	67	4	Attending a party	t	2023-06-03 23:24:56.726506	2023-06-03 23:24:56.726506
244	68	1	A maintenance worker	f	2023-06-03 23:24:56.775026	2023-06-03 23:24:56.775026
245	68	2	A property manager	t	2023-06-03 23:24:56.818533	2023-06-03 23:24:56.818533
246	68	3	A real estate agent	f	2023-06-03 23:24:56.871498	2023-06-03 23:24:56.871498
247	68	4	A bank employee	f	2023-06-03 23:24:56.922539	2023-06-03 23:24:56.922539
248	69	1	Tanaka	f	2023-06-03 23:24:56.975146	2023-06-03 23:24:56.975146
249	69	2	Zhao	f	2023-06-03 23:24:57.030948	2023-06-03 23:24:57.030948
250	69	3	Mukherjee	t	2023-06-03 23:24:57.07771	2023-06-03 23:24:57.07771
251	69	4	Tremblay	f	2023-06-03 23:24:57.120094	2023-06-03 23:24:57.120094
252	70	1	Fill out a registration form	t	2023-06-03 23:24:57.163726	2023-06-03 23:24:57.163726
253	70	2	Meet with some neighbors	f	2023-06-03 23:24:57.207093	2023-06-03 23:24:57.207093
254	70	3	Order some furniture	f	2023-06-03 23:24:57.251016	2023-06-03 23:24:57.251016
255	70	4	Make a payment	f	2023-06-03 23:24:57.305218	2023-06-03 23:24:57.305218
256	71	1	A hair salon	f	2023-06-03 23:24:57.350963	2023-06-03 23:24:57.350963
257	71	2	An insurance company	f	2023-06-03 23:24:57.394954	2023-06-03 23:24:57.394954
258	71	3	A car dealership	f	2023-06-03 23:24:57.506596	2023-06-03 23:24:57.506596
259	71	4	An eye doctor`s office	t	2023-06-03 23:24:57.552875	2023-06-03 23:24:57.552875
260	72	1	It is too far away.	f	2023-06-03 23:24:57.600013	2023-06-03 23:24:57.600013
261	72	2	It needs to be rescheduled.	t	2023-06-03 23:24:57.645377	2023-06-03 23:24:57.645377
262	72	3	It is too expensive.	f	2023-06-03 23:24:57.689268	2023-06-03 23:24:57.689268
263	72	4	It should be with a different a person.	f	2023-06-03 23:24:57.731837	2023-06-03 23:24:57.731837
264	73	1	Payment methods	f	2023-06-03 23:24:57.774332	2023-06-03 23:24:57.774332
265	73	2	Delivery options	f	2023-06-03 23:24:57.82089	2023-06-03 23:24:57.82089
266	73	3	A warranty	t	2023-06-03 23:24:57.867211	2023-06-03 23:24:57.867211
267	73	4	A job opening	f	2023-06-03 23:24:57.91013	2023-06-03 23:24:57.91013
268	74	1	A factory tour	t	2023-06-03 23:24:57.955388	2023-06-03 23:24:57.955388
269	74	2	A baking competition	f	2023-06-03 23:24:58.001518	2023-06-03 23:24:58.001518
270	74	3	A grand opening	f	2023-06-03 23:24:58.046985	2023-06-03 23:24:58.046985
271	74	4	An art show	f	2023-06-03 23:24:58.092261	2023-06-03 23:24:58.092261
272	75	1	A poster	f	2023-06-03 23:24:58.137025	2023-06-03 23:24:58.137025
273	75	2	A promotional mug	f	2023-06-03 23:24:58.194655	2023-06-03 23:24:58.194655
274	75	3	A company T-shirt	f	2023-06-03 23:24:58.280014	2023-06-03 23:24:58.280014
275	75	4	A photograph	t	2023-06-03 23:24:58.334101	2023-06-03 23:24:58.334101
276	76	1	Find a recipe	f	2023-06-03 23:24:58.384183	2023-06-03 23:24:58.384183
277	76	2	Fill out an entry form	f	2023-06-03 23:24:58.426868	2023-06-03 23:24:58.426868
278	76	3	View a product list	f	2023-06-03 23:24:58.469581	2023-06-03 23:24:58.469581
279	76	4	Download a coupon	t	2023-06-03 23:24:58.51282	2023-06-03 23:24:58.51282
280	77	1	At a sports arena	f	2023-06-03 23:24:58.555969	2023-06-03 23:24:58.555969
281	77	2	At a concert hall	f	2023-06-03 23:24:58.599643	2023-06-03 23:24:58.599643
282	77	3	At an art museum	f	2023-06-03 23:24:58.642033	2023-06-03 23:24:58.642033
283	77	4	At a movie theater	t	2023-06-03 23:24:58.701385	2023-06-03 23:24:58.701385
284	78	1	A presenter has been delayed.	f	2023-06-03 23:24:58.743909	2023-06-03 23:24:58.743909
285	78	2	Some lights have gone out.	f	2023-06-03 23:24:58.788351	2023-06-03 23:24:58.788351
286	78	3	A sound system is broken.	t	2023-06-03 23:24:58.85452	2023-06-03 23:24:58.85452
287	78	4	A construction project is noisy.	f	2023-06-03 23:24:58.991428	2023-06-03 23:24:58.991428
288	79	1	A promotional item	f	2023-06-03 23:24:59.038945	2023-06-03 23:24:59.038945
289	79	2	A parking voucher	f	2023-06-03 23:24:59.115324	2023-06-03 23:24:59.115324
290	79	3	Discounted snacks	f	2023-06-03 23:24:59.158935	2023-06-03 23:24:59.158935
291	79	4	Free tickets	t	2023-06-03 23:24:59.206943	2023-06-03 23:24:59.206943
292	80	1	A technology conference	t	2023-06-03 23:24:59.258936	2023-06-03 23:24:59.258936
293	80	2	A product demonstration	f	2023-06-03 23:24:59.306089	2023-06-03 23:24:59.306089
294	80	3	A company fund-raiser	f	2023-06-03 23:24:59.350151	2023-06-03 23:24:59.350151
295	80	4	A training workshop	f	2023-06-03 23:24:59.39267	2023-06-03 23:24:59.39267
296	81	1	To propose moving to a larger venue	f	2023-06-03 23:24:59.438947	2023-06-03 23:24:59.438947
297	81	2	To indicate that some advertising was successful	t	2023-06-03 23:24:59.484431	2023-06-03 23:24:59.484431
298	81	3	To emphasize the importance of working quickly	f	2023-06-03 23:24:59.52853	2023-06-03 23:24:59.52853
299	81	4	To suggest more volunteers are needed	f	2023-06-03 23:24:59.581486	2023-06-03 23:24:59.581486
300	82	1	Provide feedback	f	2023-06-03 23:24:59.662613	2023-06-03 23:24:59.662613
301	82	2	Silence mobile phones	f	2023-06-03 23:24:59.711983	2023-06-03 23:24:59.711983
302	82	3	Review an event program	t	2023-06-03 23:24:59.755256	2023-06-03 23:24:59.755256
303	82	4	Enjoy some refreshments	f	2023-06-03 23:24:59.798706	2023-06-03 23:24:59.798706
304	83	1	To support local businesses	f	2023-06-03 23:25:00.24824	2023-06-03 23:25:00.24824
305	83	2	To promote tourism	f	2023-06-03 23:25:00.358942	2023-06-03 23:25:00.358942
306	83	3	To decrease traffic	t	2023-06-03 23:25:00.403976	2023-06-03 23:25:00.403976
307	83	4	To reduce government spending	f	2023-06-03 23:25:00.44695	2023-06-03 23:25:00.44695
308	84	1	Commuters	t	2023-06-03 23:25:00.490262	2023-06-03 23:25:00.490262
309	84	2	Senior citizens	f	2023-06-03 23:25:00.53517	2023-06-03 23:25:00.53517
310	84	3	Students	f	2023-06-03 23:25:00.586974	2023-06-03 23:25:00.586974
311	84	4	City officials	f	2023-06-03 23:25:00.649825	2023-06-03 23:25:00.649825
312	85	1	A survey will be distributed.	f	2023-06-03 23:25:00.747778	2023-06-03 23:25:00.747778
313	85	2	A new director will take over.	f	2023-06-03 23:25:00.820093	2023-06-03 23:25:00.820093
314	85	3	A bus line will be added.	f	2023-06-03 23:25:00.896248	2023-06-03 23:25:00.896248
315	85	4	A program evaluation will take place.	t	2023-06-03 23:25:01.002452	2023-06-03 23:25:01.002452
316	86	1	A sports competition	f	2023-06-03 23:25:01.097934	2023-06-03 23:25:01.097934
317	86	2	A music festival	t	2023-06-03 23:25:01.140947	2023-06-03 23:25:01.140947
318	86	3	A cooking demonstration	f	2023-06-03 23:25:01.234955	2023-06-03 23:25:01.234955
319	86	4	A historical play	f	2023-06-03 23:25:01.335259	2023-06-03 23:25:01.335259
320	87	1	To encourage the listeners to enter a contest	t	2023-06-03 23:25:01.434397	2023-06-03 23:25:01.434397
321	87	2	To suggest that the listeners arrive early	f	2023-06-03 23:25:01.534332	2023-06-03 23:25:01.534332
322	87	3	To complain that an event space is too small	f	2023-06-03 23:25:01.636146	2023-06-03 23:25:01.636146
323	87	4	To praise the results of a marketing plan	f	2023-06-03 23:25:01.701848	2023-06-03 23:25:01.701848
324	88	1	A new venue will open.	f	2023-06-03 23:25:01.747062	2023-06-03 23:25:01.747062
325	88	2	A prize winner will be announced.	f	2023-06-03 23:25:01.835594	2023-06-03 23:25:01.835594
326	88	3	An interview will take place.	t	2023-06-03 23:25:01.938942	2023-06-03 23:25:01.938942
327	88	4	A video will be filmed.	f	2023-06-03 23:25:02.038959	2023-06-03 23:25:02.038959
328	89	1	A computer company	f	2023-06-03 23:25:02.134736	2023-06-03 23:25:02.134736
329	89	2	A construction firm	f	2023-06-03 23:25:02.197458	2023-06-03 23:25:02.197458
330	89	3	A furniture manufacturer	t	2023-06-03 23:25:02.261473	2023-06-03 23:25:02.261473
331	89	4	An office-supply distributor	f	2023-06-03 23:25:02.434344	2023-06-03 23:25:02.434344
332	90	1	It is inexpensive.	f	2023-06-03 23:25:02.480994	2023-06-03 23:25:02.480994
333	90	2	It is durable.	t	2023-06-03 23:25:02.597482	2023-06-03 23:25:02.597482
334	90	3	It is lightweight.	f	2023-06-03 23:25:02.641853	2023-06-03 23:25:02.641853
335	90	4	It comes in many colors.	f	2023-06-03 23:25:02.785101	2023-06-03 23:25:02.785101
336	91	1	Sign up for a mailing list	f	2023-06-03 23:25:02.863017	2023-06-03 23:25:02.863017
337	91	2	Watch an instructional video	f	2023-06-03 23:25:03.047047	2023-06-03 23:25:03.047047
338	91	3	Enter a contest	f	2023-06-03 23:25:03.153441	2023-06-03 23:25:03.153441
339	91	4	Look at a sample	t	2023-06-03 23:25:03.205886	2023-06-03 23:25:03.205886
340	92	1	Product Development	f	2023-06-03 23:25:03.303889	2023-06-03 23:25:03.303889
341	92	2	Human Resources	t	2023-06-03 23:25:03.36829	2023-06-03 23:25:03.36829
342	92	3	Legal	f	2023-06-03 23:25:03.41072	2023-06-03 23:25:03.41072
343	92	4	Accounting	f	2023-06-03 23:25:03.495471	2023-06-03 23:25:03.495471
344	93	1	To recommend an employee sign up for more training	f	2023-06-03 23:25:03.589494	2023-06-03 23:25:03.589494
345	93	2	To indicate that a project deadline will be extended	f	2023-06-03 23:25:03.696553	2023-06-03 23:25:03.696553
346	93	3	To approve a request to transfer	t	2023-06-03 23:25:03.788734	2023-06-03 23:25:03.788734
347	93	4	To suggest consulting with an expert	f	2023-06-03 23:25:03.831072	2023-06-03 23:25:03.831072
348	94	1	Some sales results	f	2023-06-03 23:25:03.904732	2023-06-03 23:25:03.904732
349	94	2	Some client feedback	f	2023-06-03 23:25:03.989583	2023-06-03 23:25:03.989583
350	94	3	An office renovation	f	2023-06-03 23:25:04.032256	2023-06-03 23:25:04.032256
351	94	4	A work schedule	t	2023-06-03 23:25:04.155195	2023-06-03 23:25:04.155195
352	95	1	To discuss their businesses	t	2023-06-03 23:25:04.20953	2023-06-03 23:25:04.20953
353	95	2	To talk about local history	f	2023-06-03 23:25:04.329509	2023-06-03 23:25:04.329509
354	95	3	To teach communication skills	f	2023-06-03 23:25:04.372419	2023-06-03 23:25:04.372419
355	95	4	To offer travel tips	f	2023-06-03 23:25:04.415123	2023-06-03 23:25:04.415123
356	96	1	View photos of famous guests	f	2023-06-03 23:25:04.457585	2023-06-03 23:25:04.457585
357	96	2	Sign up for a special service	f	2023-06-03 23:25:04.502972	2023-06-03 23:25:04.502972
358	96	3	Read about upcoming programs	f	2023-06-03 23:25:04.547499	2023-06-03 23:25:04.547499
359	96	4	Listen to previous episodes	t	2023-06-03 23:25:04.590111	2023-06-03 23:25:04.590111
360	97	1	Tuesday	f	2023-06-03 23:25:04.632541	2023-06-03 23:25:04.632541
361	97	2	Wednesday	f	2023-06-03 23:25:04.675224	2023-06-03 23:25:04.675224
362	97	3	Thursday	t	2023-06-03 23:25:04.717569	2023-06-03 23:25:04.717569
363	97	4	Friday	f	2023-06-03 23:25:04.762944	2023-06-03 23:25:04.762944
364	98	1	On Shelf 1	t	2023-06-03 23:25:04.838948	2023-06-03 23:25:04.838948
365	98	2	On Shelf 2	f	2023-06-03 23:25:04.883189	2023-06-03 23:25:04.883189
366	98	3	On Shelf 3	f	2023-06-03 23:25:04.934871	2023-06-03 23:25:04.934871
367	98	4	On Shelf 4	f	2023-06-03 23:25:04.977337	2023-06-03 23:25:04.977337
368	99	1	Coupons	f	2023-06-03 23:25:05.020106	2023-06-03 23:25:05.020106
369	99	2	Hats	f	2023-06-03 23:25:05.134325	2023-06-03 23:25:05.134325
370	99	3	Gloves	f	2023-06-03 23:25:05.23432	2023-06-03 23:25:05.23432
371	99	4	Socks	t	2023-06-03 23:25:05.277268	2023-06-03 23:25:05.277268
372	100	1	A payment schedule	f	2023-06-03 23:25:05.320182	2023-06-03 23:25:05.320182
373	100	2	Photographs	f	2023-06-03 23:25:05.391314	2023-06-03 23:25:05.391314
374	100	3	Shipping information	t	2023-06-03 23:25:05.480966	2023-06-03 23:25:05.480966
375	100	4	Display measurements	f	2023-06-03 23:25:05.526154	2023-06-03 23:25:05.526154
376	101	1	regional	t	2023-06-03 23:25:05.572605	2023-06-03 23:25:05.572605
377	101	2	regionally	f	2023-06-03 23:25:05.615233	2023-06-03 23:25:05.615233
378	101	3	region	f	2023-06-03 23:25:05.660164	2023-06-03 23:25:05.660164
379	101	4	regions	f	2023-06-03 23:25:05.702459	2023-06-03 23:25:05.702459
380	102	1	family	f	2023-06-03 23:25:05.745548	2023-06-03 23:25:05.745548
381	102	2	world	f	2023-06-03 23:25:05.788107	2023-06-03 23:25:05.788107
382	102	3	company	f	2023-06-03 23:25:05.846959	2023-06-03 23:25:05.846959
383	102	4	city	t	2023-06-03 23:25:05.912768	2023-06-03 23:25:05.912768
384	103	1	you	f	2023-06-03 23:25:05.955389	2023-06-03 23:25:05.955389
385	103	2	yours	f	2023-06-03 23:25:05.99817	2023-06-03 23:25:05.99817
386	103	3	yourself	f	2023-06-03 23:25:06.042378	2023-06-03 23:25:06.042378
387	103	4	your	t	2023-06-03 23:25:06.085545	2023-06-03 23:25:06.085545
388	104	1	up	f	2023-06-03 23:25:06.131108	2023-06-03 23:25:06.131108
389	104	2	except	f	2023-06-03 23:25:06.174218	2023-06-03 23:25:06.174218
390	104	3	onto	f	2023-06-03 23:25:06.216875	2023-06-03 23:25:06.216875
391	104	4	through	t	2023-06-03 23:25:06.260183	2023-06-03 23:25:06.260183
392	105	1	to arrange	t	2023-06-03 23:25:06.309608	2023-06-03 23:25:06.309608
393	105	2	arranging	f	2023-06-03 23:25:06.352596	2023-06-03 23:25:06.352596
394	105	3	having arranged	f	2023-06-03 23:25:06.3993	2023-06-03 23:25:06.3993
395	105	4	arrangement	f	2023-06-03 23:25:06.442285	2023-06-03 23:25:06.442285
396	106	1	regularly	f	2023-06-03 23:25:06.485071	2023-06-03 23:25:06.485071
397	106	2	conveniently	t	2023-06-03 23:25:06.527678	2023-06-03 23:25:06.527678
398	106	3	brightly	f	2023-06-03 23:25:06.570211	2023-06-03 23:25:06.570211
399	106	4	collectively	f	2023-06-03 23:25:06.612872	2023-06-03 23:25:06.612872
400	107	1	are delayed	f	2023-06-03 23:25:06.655341	2023-06-03 23:25:06.655341
401	107	2	to delay	f	2023-06-03 23:25:06.697605	2023-06-03 23:25:06.697605
402	107	3	delays	t	2023-06-03 23:25:06.741895	2023-06-03 23:25:06.741895
403	107	4	had delayed	f	2023-06-03 23:25:06.835477	2023-06-03 23:25:06.835477
404	108	1	as a result	f	2023-06-03 23:25:06.901571	2023-06-03 23:25:06.901571
405	108	2	in addition	f	2023-06-03 23:25:06.948216	2023-06-03 23:25:06.948216
406	108	3	although	f	2023-06-03 23:25:07.000096	2023-06-03 23:25:07.000096
407	108	4	before	t	2023-06-03 23:25:07.043305	2023-06-03 23:25:07.043305
408	109	1	clear	f	2023-06-03 23:25:07.086107	2023-06-03 23:25:07.086107
409	109	2	clearing	f	2023-06-03 23:25:07.139604	2023-06-03 23:25:07.139604
410	109	3	clearest	f	2023-06-03 23:25:07.185158	2023-06-03 23:25:07.185158
411	109	4	clearly	t	2023-06-03 23:25:07.230973	2023-06-03 23:25:07.230973
412	110	1	recognized	t	2023-06-03 23:25:07.275097	2023-06-03 23:25:07.275097
413	110	2	permitted	f	2023-06-03 23:25:07.319184	2023-06-03 23:25:07.319184
414	110	3	prepared	f	2023-06-03 23:25:07.375036	2023-06-03 23:25:07.375036
415	110	4	controlled	f	2023-06-03 23:25:07.427077	2023-06-03 23:25:07.427077
416	111	1	later	f	2023-06-03 23:25:07.475467	2023-06-03 23:25:07.475467
417	111	2	after	t	2023-06-03 23:25:07.521323	2023-06-03 23:25:07.521323
418	111	3	than	f	2023-06-03 23:25:07.566357	2023-06-03 23:25:07.566357
419	111	4	often	f	2023-06-03 23:25:07.615029	2023-06-03 23:25:07.615029
420	112	1	adjusted	f	2023-06-03 23:25:07.664562	2023-06-03 23:25:07.664562
421	112	2	advanced	t	2023-06-03 23:25:07.709545	2023-06-03 23:25:07.709545
422	112	3	eager	f	2023-06-03 23:25:07.763087	2023-06-03 23:25:07.763087
423	112	4	faithful	f	2023-06-03 23:25:07.817858	2023-06-03 23:25:07.817858
424	113	1	evaluation	f	2023-06-03 23:25:07.877639	2023-06-03 23:25:07.877639
425	113	2	evaluate	f	2023-06-03 23:25:07.922948	2023-06-03 23:25:07.922948
426	113	3	evaluating	t	2023-06-03 23:25:07.96971	2023-06-03 23:25:07.96971
427	113	4	evaluated	f	2023-06-03 23:25:08.034942	2023-06-03 23:25:08.034942
428	114	1	on	f	2023-06-03 23:25:08.091175	2023-06-03 23:25:08.091175
429	114	2	for	t	2023-06-03 23:25:08.134634	2023-06-03 23:25:08.134634
430	114	3	to	f	2023-06-03 23:25:08.227127	2023-06-03 23:25:08.227127
431	114	4	under	f	2023-06-03 23:25:08.287154	2023-06-03 23:25:08.287154
432	115	1	create	f	2023-06-03 23:25:08.358972	2023-06-03 23:25:08.358972
433	115	2	creativity	f	2023-06-03 23:25:08.404534	2023-06-03 23:25:08.404534
434	115	3	creation	f	2023-06-03 23:25:08.454795	2023-06-03 23:25:08.454795
435	115	4	creative	t	2023-06-03 23:25:08.499994	2023-06-03 23:25:08.499994
436	116	1	even	f	2023-06-03 23:25:08.547536	2023-06-03 23:25:08.547536
437	116	2	unless	t	2023-06-03 23:25:08.636243	2023-06-03 23:25:08.636243
438	116	3	similarly	f	2023-06-03 23:25:08.709437	2023-06-03 23:25:08.709437
439	116	4	also	f	2023-06-03 23:25:08.759238	2023-06-03 23:25:08.759238
440	117	1	renew	f	2023-06-03 23:25:08.803784	2023-06-03 23:25:08.803784
441	117	2	renewed	f	2023-06-03 23:25:08.868061	2023-06-03 23:25:08.868061
442	117	3	renewals	t	2023-06-03 23:25:08.926949	2023-06-03 23:25:08.926949
443	117	4	to renew	f	2023-06-03 23:25:08.983543	2023-06-03 23:25:08.983543
444	118	1	careful	f	2023-06-03 23:25:09.038765	2023-06-03 23:25:09.038765
445	118	2	helpful	f	2023-06-03 23:25:09.110951	2023-06-03 23:25:09.110951
446	118	3	confident	t	2023-06-03 23:25:09.156823	2023-06-03 23:25:09.156823
447	118	4	durable	f	2023-06-03 23:25:09.207354	2023-06-03 23:25:09.207354
448	119	1	consistent	f	2023-06-03 23:25:09.255386	2023-06-03 23:25:09.255386
449	119	2	consist	f	2023-06-03 23:25:09.301601	2023-06-03 23:25:09.301601
450	119	3	consistently	t	2023-06-03 23:25:09.347005	2023-06-03 23:25:09.347005
451	119	4	consisting	f	2023-06-03 23:25:09.397508	2023-06-03 23:25:09.397508
452	120	1	launch	t	2023-06-03 23:25:09.451946	2023-06-03 23:25:09.451946
453	120	2	facilitate	f	2023-06-03 23:25:09.501294	2023-06-03 23:25:09.501294
454	120	3	arise	f	2023-06-03 23:25:09.55125	2023-06-03 23:25:09.55125
455	120	4	exert	f	2023-06-03 23:25:09.594216	2023-06-03 23:25:09.594216
456	121	1	if	t	2023-06-03 23:25:09.639081	2023-06-03 23:25:09.639081
457	121	2	yet	f	2023-06-03 23:25:09.708311	2023-06-03 23:25:09.708311
458	121	3	until	f	2023-06-03 23:25:09.779225	2023-06-03 23:25:09.779225
459	121	4	neither	f	2023-06-03 23:25:09.829861	2023-06-03 23:25:09.829861
460	122	1	majority	f	2023-06-03 23:25:09.886522	2023-06-03 23:25:09.886522
461	122	2	edition	f	2023-06-03 23:25:09.928779	2023-06-03 23:25:09.928779
462	122	3	volume	t	2023-06-03 23:25:09.9723	2023-06-03 23:25:09.9723
463	122	4	economy	f	2023-06-03 23:25:10.015228	2023-06-03 23:25:10.015228
464	123	1	coordinated	f	2023-06-03 23:25:10.058946	2023-06-03 23:25:10.058946
465	123	2	to coordinate	f	2023-06-03 23:25:10.10452	2023-06-03 23:25:10.10452
466	123	3	coordination	f	2023-06-03 23:25:10.147943	2023-06-03 23:25:10.147943
467	123	4	be coordinating	t	2023-06-03 23:25:10.212812	2023-06-03 23:25:10.212812
468	124	1	significantly	t	2023-06-03 23:25:10.314435	2023-06-03 23:25:10.314435
469	124	2	persuasively	f	2023-06-03 23:25:10.362415	2023-06-03 23:25:10.362415
470	124	3	proficiently	f	2023-06-03 23:25:10.409485	2023-06-03 23:25:10.409485
471	124	4	gladly	f	2023-06-03 23:25:10.469848	2023-06-03 23:25:10.469848
472	125	1	substituted	f	2023-06-03 23:25:10.513463	2023-06-03 23:25:10.513463
473	125	2	substituting	f	2023-06-03 23:25:10.611072	2023-06-03 23:25:10.611072
474	125	3	substitutions	t	2023-06-03 23:25:10.70989	2023-06-03 23:25:10.70989
475	125	4	substitute	f	2023-06-03 23:25:10.770853	2023-06-03 23:25:10.770853
476	126	1	inform	f	2023-06-03 23:25:10.830487	2023-06-03 23:25:10.830487
477	126	2	succeed	f	2023-06-03 23:25:10.935526	2023-06-03 23:25:10.935526
478	126	3	estimate	f	2023-06-03 23:25:11.006999	2023-06-03 23:25:11.006999
479	126	4	establish	t	2023-06-03 23:25:11.065042	2023-06-03 23:25:11.065042
480	127	1	Happily	f	2023-06-03 23:25:11.107538	2023-06-03 23:25:11.107538
481	127	2	Now that	t	2023-06-03 23:25:11.150209	2023-06-03 23:25:11.150209
482	127	3	Despite	f	2023-06-03 23:25:11.23537	2023-06-03 23:25:11.23537
483	127	4	In fact	f	2023-06-03 23:25:11.336088	2023-06-03 23:25:11.336088
484	128	1	readily	f	2023-06-03 23:25:11.434955	2023-06-03 23:25:11.434955
485	128	2	diligently	t	2023-06-03 23:25:11.538954	2023-06-03 23:25:11.538954
486	128	3	curiously	f	2023-06-03 23:25:11.63509	2023-06-03 23:25:11.63509
487	128	4	extremely	f	2023-06-03 23:25:11.734955	2023-06-03 23:25:11.734955
488	129	1	whose	f	2023-06-03 23:25:11.835759	2023-06-03 23:25:11.835759
489	129	2	his	f	2023-06-03 23:25:11.887191	2023-06-03 23:25:11.887191
490	129	3	its	t	2023-06-03 23:25:11.929666	2023-06-03 23:25:11.929666
491	129	4	this	f	2023-06-03 23:25:12.034325	2023-06-03 23:25:12.034325
492	130	1	thus	f	2023-06-03 23:25:12.083759	2023-06-03 23:25:12.083759
493	130	2	as well as	t	2023-06-03 23:25:12.137395	2023-06-03 23:25:12.137395
494	130	3	at last	f	2023-06-03 23:25:12.187082	2023-06-03 23:25:12.187082
495	130	4	accordingly	f	2023-06-03 23:25:12.27771	2023-06-03 23:25:12.27771
496	131	1	serve	f	2023-06-03 23:25:12.434946	2023-06-03 23:25:12.434946
497	131	2	served	f	2023-06-03 23:25:12.477636	2023-06-03 23:25:12.477636
498	131	3	server	f	2023-06-03 23:25:12.519971	2023-06-03 23:25:12.519971
499	131	4	service	t	2023-06-03 23:25:12.563257	2023-06-03 23:25:12.563257
500	132	1	Along	f	2023-06-03 23:25:12.678986	2023-06-03 23:25:12.678986
501	132	2	During	t	2023-06-03 23:25:12.730874	2023-06-03 23:25:12.730874
502	132	3	Without	f	2023-06-03 23:25:12.93443	2023-06-03 23:25:12.93443
503	132	4	Between	f	2023-06-03 23:25:13.034497	2023-06-03 23:25:13.034497
504	133	1	apologize	t	2023-06-03 23:25:13.077456	2023-06-03 23:25:13.077456
505	133	2	organize	f	2023-06-03 23:25:13.330271	2023-06-03 23:25:13.330271
506	133	3	realize	f	2023-06-03 23:25:13.463705	2023-06-03 23:25:13.463705
507	133	4	recognize	f	2023-06-03 23:25:13.52295	2023-06-03 23:25:13.52295
508	134	1	If you would like to join our property management team, call us today.	f	2023-06-03 23:25:13.56604	2023-06-03 23:25:13.56604
509	134	2	Thank you for your patience while the main lobby is being painted.	f	2023-06-03 23:25:13.614841	2023-06-03 23:25:13.614841
510	134	3	Please do not attempt to access the north lobby on these days.	f	2023-06-03 23:25:13.659342	2023-06-03 23:25:13.659342
511	134	4	Questions or comments may be directed to the Management office.	t	2023-06-03 23:25:13.701994	2023-06-03 23:25:13.701994
512	135	1	quickly	t	2023-06-03 23:25:13.744671	2023-06-03 23:25:13.744671
513	135	2	quicken	f	2023-06-03 23:25:13.789548	2023-06-03 23:25:13.789548
514	135	3	quickest	f	2023-06-03 23:25:13.853222	2023-06-03 23:25:13.853222
515	135	4	quickness	f	2023-06-03 23:25:13.895762	2023-06-03 23:25:13.895762
516	136	1	as far as	f	2023-06-03 23:25:13.93895	2023-06-03 23:25:13.93895
517	136	2	even though	t	2023-06-03 23:25:13.984102	2023-06-03 23:25:13.984102
518	136	3	such as	f	2023-06-03 23:25:14.027132	2023-06-03 23:25:14.027132
519	136	4	whether	f	2023-06-03 23:25:14.069617	2023-06-03 23:25:14.069617
520	137	1	Of course, the shop is busiest on Saturdays.	f	2023-06-03 23:25:14.112317	2023-06-03 23:25:14.112317
521	137	2	The suit fits me perfectly too.	t	2023-06-03 23:25:14.15672	2023-06-03 23:25:14.15672
522	137	3	I made another purchase.	f	2023-06-03 23:25:14.199454	2023-06-03 23:25:14.199454
523	137	4	He used to sell shirts.	f	2023-06-03 23:25:14.247125	2023-06-03 23:25:14.247125
524	138	1	former	f	2023-06-03 23:25:14.289817	2023-06-03 23:25:14.289817
525	138	2	temporary	f	2023-06-03 23:25:14.332363	2023-06-03 23:25:14.332363
526	138	3	superb	t	2023-06-03 23:25:14.430218	2023-06-03 23:25:14.430218
527	138	4	best	f	2023-06-03 23:25:14.476837	2023-06-03 23:25:14.476837
528	139	1	In the event of bad weather, the animals will be inside.	f	2023-06-03 23:25:14.520162	2023-06-03 23:25:14.520162
529	139	2	There are no exceptions to this policy.	t	2023-06-03 23:25:14.564374	2023-06-03 23:25:14.564374
530	139	3	Ones younger than that can find much to enjoy.	f	2023-06-03 23:25:14.606737	2023-06-03 23:25:14.606737
531	139	4	This fee includes lunch and a small a souvenir.	f	2023-06-03 23:25:14.64909	2023-06-03 23:25:14.64909
532	140	1	legal	f	2023-06-03 23:25:14.691429	2023-06-03 23:25:14.691429
533	140	2	artistic	f	2023-06-03 23:25:14.733859	2023-06-03 23:25:14.733859
534	140	3	athletic	f	2023-06-03 23:25:14.78098	2023-06-03 23:25:14.78098
535	140	4	educational	t	2023-06-03 23:25:14.824608	2023-06-03 23:25:14.824608
536	141	1	events	t	2023-06-03 23:25:14.874252	2023-06-03 23:25:14.874252
537	141	2	plays	f	2023-06-03 23:25:14.924094	2023-06-03 23:25:14.924094
538	141	3	treatments	f	2023-06-03 23:25:14.97747	2023-06-03 23:25:14.97747
539	141	4	trips	f	2023-06-03 23:25:15.021335	2023-06-03 23:25:15.021335
540	142	1	they	f	2023-06-03 23:25:15.064485	2023-06-03 23:25:15.064485
541	142	2	me	t	2023-06-03 23:25:15.107129	2023-06-03 23:25:15.107129
542	142	3	her	f	2023-06-03 23:25:15.149777	2023-06-03 23:25:15.149777
543	142	4	one	f	2023-06-03 23:25:15.19228	2023-06-03 23:25:15.19228
544	143	1	prouder	f	2023-06-03 23:25:15.234841	2023-06-03 23:25:15.234841
545	143	2	proudly	f	2023-06-03 23:25:15.277606	2023-06-03 23:25:15.277606
546	143	3	pride	f	2023-06-03 23:25:15.321191	2023-06-03 23:25:15.321191
547	143	4	proud	t	2023-06-03 23:25:15.369866	2023-06-03 23:25:15.369866
548	144	1	They include general and cosmetic procedures.	t	2023-06-03 23:25:15.458132	2023-06-03 23:25:15.458132
549	144	2	We have relocated from neighboring Hillsborough.	f	2023-06-03 23:25:15.501855	2023-06-03 23:25:15.501855
550	144	3	The Web site is a creation of A to Z Host Builders.	f	2023-06-03 23:25:15.544484	2023-06-03 23:25:15.544484
551	144	4	Several of them are surprisingly expensive.	f	2023-06-03 23:25:15.58849	2023-06-03 23:25:15.58849
552	145	1	scheduled	f	2023-06-03 23:25:15.632183	2023-06-03 23:25:15.632183
553	145	2	to schedule	t	2023-06-03 23:25:15.674311	2023-06-03 23:25:15.674311
554	145	3	scheduling	f	2023-06-03 23:25:15.716979	2023-06-03 23:25:15.716979
555	145	4	being scheduled	f	2023-06-03 23:25:15.759867	2023-06-03 23:25:15.759867
556	146	1	shoppers	f	2023-06-03 23:25:15.808818	2023-06-03 23:25:15.808818
557	146	2	residents	f	2023-06-03 23:25:15.929568	2023-06-03 23:25:15.929568
558	146	3	patients	t	2023-06-03 23:25:15.977542	2023-06-03 23:25:15.977542
559	146	4	tenants	f	2023-06-03 23:25:16.021994	2023-06-03 23:25:16.021994
560	147	1	To report on airport renovations	f	2023-06-03 23:25:16.064822	2023-06-03 23:25:16.064822
561	147	2	To give an update on a technical problem	t	2023-06-03 23:25:16.119788	2023-06-03 23:25:16.119788
562	147	3	To introduce a new reservation system	f	2023-06-03 23:25:16.164162	2023-06-03 23:25:16.164162
563	147	4	To advertise airline routes to some new cities	f	2023-06-03 23:25:16.20643	2023-06-03 23:25:16.20643
564	148	1	The number of flights available	f	2023-06-03 23:25:16.248719	2023-06-03 23:25:16.248719
565	148	2	Dining options on flights	f	2023-06-03 23:25:16.292131	2023-06-03 23:25:16.292131
566	148	3	Assistance for customers at airports	t	2023-06-03 23:25:16.336465	2023-06-03 23:25:16.336465
567	148	4	Prices for international flights	f	2023-06-03 23:25:16.393537	2023-06-03 23:25:16.393537
568	149	1	Experience in video production	f	2023-06-03 23:25:16.473516	2023-06-03 23:25:16.473516
569	149	2	Certain pieces of equipment	t	2023-06-03 23:25:16.529615	2023-06-03 23:25:16.529615
570	149	3	A university degree in language studies	f	2023-06-03 23:25:16.572117	2023-06-03 23:25:16.572117
571	149	4	An office with a reception area	f	2023-06-03 23:25:16.615743	2023-06-03 23:25:16.615743
572	150	1	It is a full-time position.	f	2023-06-03 23:25:16.658295	2023-06-03 23:25:16.658295
573	150	2	It pays a fixed salary.	f	2023-06-03 23:25:16.700812	2023-06-03 23:25:16.700812
574	150	3	It involves some foreign travel.	f	2023-06-03 23:25:16.746989	2023-06-03 23:25:16.746989
575	150	4	It offers a choice of assignments.	t	2023-06-03 23:25:16.793093	2023-06-03 23:25:16.793093
576	151	1	It included multiple versions of Konserted.	f	2023-06-03 23:25:16.850292	2023-06-03 23:25:16.850292
577	151	2	It was done over several days.	t	2023-06-03 23:25:16.90101	2023-06-03 23:25:16.90101
578	151	3	It required participants to complete a survey.	f	2023-06-03 23:25:16.946389	2023-06-03 23:25:16.946389
579	151	4	It took place at a series of concerts.	f	2023-06-03 23:25:17.00143	2023-06-03 23:25:17.00143
580	152	1	Searching for an event	f	2023-06-03 23:25:17.071578	2023-06-03 23:25:17.071578
581	152	2	Searching for friends	f	2023-06-03 23:25:17.115329	2023-06-03 23:25:17.115329
582	152	3	Inviting friends to a performance	t	2023-06-03 23:25:17.159403	2023-06-03 23:25:17.159403
583	152	4	Posting reviews to a Web site	f	2023-06-03 23:25:17.201885	2023-06-03 23:25:17.201885
584	153	1	It was very well attended.	t	2023-06-03 23:25:17.245402	2023-06-03 23:25:17.245402
585	153	2	It was moved to a larger venue.	f	2023-06-03 23:25:17.292438	2023-06-03 23:25:17.292438
586	153	3	It featured a musical performance.	f	2023-06-03 23:25:17.339994	2023-06-03 23:25:17.339994
587	153	4	It took place at the Koros Hall.	f	2023-06-03 23:25:17.38573	2023-06-03 23:25:17.38573
588	154	1	40	f	2023-06-03 23:25:17.450986	2023-06-03 23:25:17.450986
589	154	2	50	f	2023-06-03 23:25:17.493848	2023-06-03 23:25:17.493848
590	154	3	120	f	2023-06-03 23:25:17.537568	2023-06-03 23:25:17.537568
591	154	4	270	t	2023-06-03 23:25:17.583064	2023-06-03 23:25:17.583064
592	155	1	On September 17	f	2023-06-03 23:25:17.629461	2023-06-03 23:25:17.629461
593	155	2	On September 18	f	2023-06-03 23:25:17.673198	2023-06-03 23:25:17.673198
594	155	3	On September 19	f	2023-06-03 23:25:17.729658	2023-06-03 23:25:17.729658
595	155	4	On September 20	t	2023-06-03 23:25:17.802514	2023-06-03 23:25:17.802514
596	156	1	A construction firm	t	2023-06-03 23:25:17.846965	2023-06-03 23:25:17.846965
597	156	2	A real estate agency	f	2023-06-03 23:25:17.892383	2023-06-03 23:25:17.892383
598	156	3	A cargo-handling company	f	2023-06-03 23:25:17.934947	2023-06-03 23:25:17.934947
599	156	4	A financial services provider	f	2023-06-03 23:25:17.980047	2023-06-03 23:25:17.980047
600	157	1	It needs more funding from investors.	f	2023-06-03 23:25:18.024985	2023-06-03 23:25:18.024985
601	157	2	It will take years to finish.	t	2023-06-03 23:25:18.072553	2023-06-03 23:25:18.072553
602	157	3	It was proposed by airport officials.	f	2023-06-03 23:25:18.120818	2023-06-03 23:25:18.120818
603	157	4	It offers discounted tickets to city residents.	f	2023-06-03 23:25:18.165834	2023-06-03 23:25:18.165834
604	158	1	[1]	t	2023-06-03 23:25:18.209602	2023-06-03 23:25:18.209602
605	158	2	[2]	f	2023-06-03 23:25:18.256753	2023-06-03 23:25:18.256753
606	158	3	[3]	f	2023-06-03 23:25:18.31769	2023-06-03 23:25:18.31769
607	158	4	[4]	f	2023-06-03 23:25:18.385121	2023-06-03 23:25:18.385121
608	159	1	She did not have any issues logging on to her computer.	f	2023-06-03 23:25:18.451022	2023-06-03 23:25:18.451022
609	159	2	She does not think a document has errors.	f	2023-06-03 23:25:18.494459	2023-06-03 23:25:18.494459
610	159	3	She is willing to review a document.	t	2023-06-03 23:25:18.538957	2023-06-03 23:25:18.538957
611	159	4	She has time to meet representatives from Keyes Elegant Home.	f	2023-06-03 23:25:18.591075	2023-06-03 23:25:18.591075
612	160	1	Marketing	t	2023-06-03 23:25:18.638971	2023-06-03 23:25:18.638971
613	160	2	Accounting	f	2023-06-03 23:25:18.68359	2023-06-03 23:25:18.68359
614	160	3	Legal consulting	f	2023-06-03 23:25:18.743714	2023-06-03 23:25:18.743714
615	160	4	Information technology services	f	2023-06-03 23:25:18.866995	2023-06-03 23:25:18.866995
616	161	1	It takes place in downtown Staffordsville.	f	2023-06-03 23:25:18.91354	2023-06-03 23:25:18.91354
617	161	2	It is being held for the first time.	f	2023-06-03 23:25:18.959188	2023-06-03 23:25:18.959188
618	161	3	It specializes in locally produced crafts.	f	2023-06-03 23:25:19.004656	2023-06-03 23:25:19.004656
619	161	4	It will be held outdoors.	t	2023-06-03 23:25:19.051369	2023-06-03 23:25:19.051369
620	162	1	Sharing a space with another participant	t	2023-06-03 23:25:19.095272	2023-06-03 23:25:19.095272
621	162	2	Paying a fee to participate	f	2023-06-03 23:25:19.143066	2023-06-03 23:25:19.143066
622	162	3	Submitting images of the crafts	f	2023-06-03 23:25:19.187778	2023-06-03 23:25:19.187778
623	162	4	Providing one`s own tenting	f	2023-06-03 23:25:19.231715	2023-06-03 23:25:19.231715
624	163	1	Sketches	f	2023-06-03 23:25:19.285498	2023-06-03 23:25:19.285498
625	163	2	Photographs	f	2023-06-03 23:25:19.338335	2023-06-03 23:25:19.338335
626	163	3	Pottery	f	2023-06-03 23:25:19.389608	2023-06-03 23:25:19.389608
627	163	4	Jewelry	t	2023-06-03 23:25:19.473611	2023-06-03 23:25:19.473611
628	164	1	[1]	t	2023-06-03 23:25:19.516186	2023-06-03 23:25:19.516186
629	164	2	[2]	f	2023-06-03 23:25:19.558529	2023-06-03 23:25:19.558529
630	164	3	[3]	f	2023-06-03 23:25:19.604599	2023-06-03 23:25:19.604599
631	164	4	[4]	f	2023-06-03 23:25:19.647652	2023-06-03 23:25:19.647652
632	165	1	Real estate	f	2023-06-03 23:25:19.700903	2023-06-03 23:25:19.700903
633	165	2	Life insurance	f	2023-06-03 23:25:19.744158	2023-06-03 23:25:19.744158
634	165	3	Home security	t	2023-06-03 23:25:19.790024	2023-06-03 23:25:19.790024
635	165	4	Furniture moving	f	2023-06-03 23:25:19.83425	2023-06-03 23:25:19.83425
636	166	1	An outdoor motion sensor	f	2023-06-03 23:25:19.881627	2023-06-03 23:25:19.881627
637	166	2	A smartphone application	t	2023-06-03 23:25:19.970994	2023-06-03 23:25:19.970994
638	166	3	Home installation service	f	2023-06-03 23:25:20.013733	2023-06-03 23:25:20.013733
639	166	4	Fire detection equipment	f	2023-06-03 23:25:20.056531	2023-06-03 23:25:20.056531
640	167	1	greet	f	2023-06-03 23:25:20.101639	2023-06-03 23:25:20.101639
641	167	2	touch	f	2023-06-03 23:25:20.14492	2023-06-03 23:25:20.14492
642	167	3	satisfy	t	2023-06-03 23:25:20.188814	2023-06-03 23:25:20.188814
643	167	4	experience	f	2023-06-03 23:25:20.23148	2023-06-03 23:25:20.23148
644	168	1	To announce a name change	t	2023-06-03 23:25:20.275721	2023-06-03 23:25:20.275721
645	168	2	To honor distinguished alumni	f	2023-06-03 23:25:20.32477	2023-06-03 23:25:20.32477
646	168	3	To suggest revisions to a curriculum	f	2023-06-03 23:25:20.368132	2023-06-03 23:25:20.368132
647	168	4	To list an individual`s accomplishments	f	2023-06-03 23:25:20.417777	2023-06-03 23:25:20.417777
648	169	1	affected	f	2023-06-03 23:25:20.474069	2023-06-03 23:25:20.474069
649	169	2	founded	t	2023-06-03 23:25:20.546576	2023-06-03 23:25:20.546576
650	169	3	confirmed	f	2023-06-03 23:25:20.592645	2023-06-03 23:25:20.592645
651	169	4	settled	f	2023-06-03 23:25:20.638358	2023-06-03 23:25:20.638358
652	170	1	She plans to attend JATA`s anniversary celebration.	f	2023-06-03 23:25:20.686964	2023-06-03 23:25:20.686964
653	170	2	She has taught courses in cybersecurity,	f	2023-06-03 23:25:20.730778	2023-06-03 23:25:20.730778
654	170	3	She can take part in JATA`s logo design contest.	t	2023-06-03 23:25:20.77355	2023-06-03 23:25:20.77355
655	170	4	She served on JATA`s Board of Trustees.	f	2023-06-03 23:25:20.842216	2023-06-03 23:25:20.842216
656	171	1	Its professors live on campus.	t	2023-06-03 23:25:20.891909	2023-06-03 23:25:20.891909
657	171	2	Its students have access to modern equipment.	f	2023-06-03 23:25:20.942943	2023-06-03 23:25:20.942943
658	171	3	It will be twenty years old on June 1.	f	2023-06-03 23:25:21.038993	2023-06-03 23:25:21.038993
659	171	4	It is attended by international students.	f	2023-06-03 23:25:21.134331	2023-06-03 23:25:21.134331
660	172	1	A book publisher	f	2023-06-03 23:25:21.200099	2023-06-03 23:25:21.200099
661	172	2	A newspaper	t	2023-06-03 23:25:21.242968	2023-06-03 23:25:21.242968
662	172	3	A film production company	f	2023-06-03 23:25:21.287557	2023-06-03 23:25:21.287557
663	172	4	A job-placement firm	f	2023-06-03 23:25:21.565649	2023-06-03 23:25:21.565649
664	173	1	She would like to participate in an interview.	f	2023-06-03 23:25:21.651155	2023-06-03 23:25:21.651155
665	173	2	She does not think Mr. Erickson should be hired.	f	2023-06-03 23:25:21.734332	2023-06-03 23:25:21.734332
666	173	3	She feels comfortable fulfilling a request.	t	2023-06-03 23:25:21.780661	2023-06-03 23:25:21.780661
667	173	4	She has not read Mr. Erickson`s writing.	f	2023-06-03 23:25:21.823198	2023-06-03 23:25:21.823198
668	174	1	He has never been on a job interview before.	f	2023-06-03 23:25:21.865515	2023-06-03 23:25:21.865515
669	174	2	He has held many different types of jobs.	t	2023-06-03 23:25:21.983397	2023-06-03 23:25:21.983397
670	174	3	He is taking over Mr. Peters` position.	f	2023-06-03 23:25:22.032291	2023-06-03 23:25:22.032291
671	174	4	He is a former colleague of Ms. Montaine.	f	2023-06-03 23:25:22.147482	2023-06-03 23:25:22.147482
672	175	1	Prior news reporting experience	f	2023-06-03 23:25:22.190963	2023-06-03 23:25:22.190963
673	175	2	Ability to begin working immediately	f	2023-06-03 23:25:22.242571	2023-06-03 23:25:22.242571
674	175	3	Communicating well with colleagues	f	2023-06-03 23:25:22.334334	2023-06-03 23:25:22.334334
675	175	4	Staying with the company over the long term	t	2023-06-03 23:25:22.434337	2023-06-03 23:25:22.434337
676	176	1	Using plants to decorate cubicles	f	2023-06-03 23:25:22.534324	2023-06-03 23:25:22.534324
677	176	2	Walking outdoors during breaks	f	2023-06-03 23:25:22.634332	2023-06-03 23:25:22.634332
678	176	3	Using a calming noise machine	t	2023-06-03 23:25:22.750994	2023-06-03 23:25:22.750994
679	176	4	Decorating with personal photographs	f	2023-06-03 23:25:22.834381	2023-06-03 23:25:22.834381
680	177	1	Because they are relatively expensive	f	2023-06-03 23:25:22.938974	2023-06-03 23:25:22.938974
681	177	2	Because they bname natural light	t	2023-06-03 23:25:22.981663	2023-06-03 23:25:22.981663
682	177	3	Because they are to hard to match to furniture	f	2023-06-03 23:25:23.034316	2023-06-03 23:25:23.034316
683	177	4	Because they attract dust	f	2023-06-03 23:25:23.08157	2023-06-03 23:25:23.08157
684	178	1	It is the only business publication in Alberta.	f	2023-06-03 23:25:23.133484	2023-06-03 23:25:23.133484
685	178	2	Its publisher is hiring additional staff.	f	2023-06-03 23:25:23.189677	2023-06-03 23:25:23.189677
686	178	3	Its editors would like to hear from readers.	t	2023-06-03 23:25:23.232095	2023-06-03 23:25:23.232095
687	178	4	It is sponsored by a furniture company.	f	2023-06-03 23:25:23.275548	2023-06-03 23:25:23.275548
688	179	1	She is a professional writer.	f	2023-06-03 23:25:23.319221	2023-06-03 23:25:23.319221
689	179	2	She is starting a new company.	f	2023-06-03 23:25:23.361711	2023-06-03 23:25:23.361711
690	179	3	She travels frequently in her work.	f	2023-06-03 23:25:23.405809	2023-06-03 23:25:23.405809
691	179	4	She read the previous issue of Alberta Business Matters.	t	2023-06-03 23:25:23.449978	2023-06-03 23:25:23.449978
692	180	1	They are packable.	t	2023-06-03 23:25:23.494594	2023-06-03 23:25:23.494594
693	180	2	They are affordable.	f	2023-06-03 23:25:23.549838	2023-06-03 23:25:23.549838
694	180	3	They are available for a short time.	f	2023-06-03 23:25:23.668442	2023-06-03 23:25:23.668442
695	180	4	They are made from recycled materials.	f	2023-06-03 23:25:23.71222	2023-06-03 23:25:23.71222
696	181	1	It uses a double-decker bus.	f	2023-06-03 23:25:23.754759	2023-06-03 23:25:23.754759
697	181	2	It includes multiple meals at famous restaurants.	f	2023-06-03 23:25:23.801044	2023-06-03 23:25:23.801044
698	181	3	It allows participants to see London from the water.	t	2023-06-03 23:25:23.846377	2023-06-03 23:25:23.846377
699	181	4	It takes the entire day.	f	2023-06-03 23:25:23.891515	2023-06-03 23:25:23.891515
700	182	1	Transportation from hotels	f	2023-06-03 23:25:23.934334	2023-06-03 23:25:23.934334
701	182	2	A tour guide	t	2023-06-03 23:25:24.021503	2023-06-03 23:25:24.021503
702	182	3	Breakfast at a restaurant	f	2023-06-03 23:25:24.08546	2023-06-03 23:25:24.08546
703	182	4	A ticket to the London Eye	f	2023-06-03 23:25:24.127967	2023-06-03 23:25:24.127967
704	183	1	Tour 2	t	2023-06-03 23:25:24.170676	2023-06-03 23:25:24.170676
705	183	2	Tour 3	f	2023-06-03 23:25:24.214007	2023-06-03 23:25:24.214007
706	183	3	Tour 4	f	2023-06-03 23:25:24.258951	2023-06-03 23:25:24.258951
707	183	4	Tour 5	f	2023-06-03 23:25:24.304026	2023-06-03 23:25:24.304026
708	184	1	She prefers bus tours.	f	2023-06-03 23:25:24.433573	2023-06-03 23:25:24.433573
709	184	2	She speaks French.	t	2023-06-03 23:25:24.478259	2023-06-03 23:25:24.478259
710	184	3	She was on a business trip.	f	2023-06-03 23:25:24.523025	2023-06-03 23:25:24.523025
711	184	4	She used LTC before.	f	2023-06-03 23:25:24.571599	2023-06-03 23:25:24.571599
712	185	1	It was expensive.	f	2023-06-03 23:25:24.624446	2023-06-03 23:25:24.624446
713	185	2	It was disorganized.	f	2023-06-03 23:25:24.670676	2023-06-03 23:25:24.670676
714	185	3	It was in a very crowded area.	t	2023-06-03 23:25:24.733859	2023-06-03 23:25:24.733859
715	185	4	It was in an uninteresting part of the city.	f	2023-06-03 23:25:24.838961	2023-06-03 23:25:24.838961
716	186	1	Financial consulting	f	2023-06-03 23:25:24.887498	2023-06-03 23:25:24.887498
717	186	2	Graphic design	t	2023-06-03 23:25:24.93429	2023-06-03 23:25:24.93429
718	186	3	Marketing strategies	f	2023-06-03 23:25:24.980414	2023-06-03 23:25:24.980414
719	186	4	Business writing	f	2023-06-03 23:25:25.023157	2023-06-03 23:25:25.023157
720	187	1	He attended the seminar with a coworker.	f	2023-06-03 23:25:25.071354	2023-06-03 23:25:25.071354
721	187	2	He gave a presentation at the seminar.	f	2023-06-03 23:25:25.115362	2023-06-03 23:25:25.115362
722	187	3	He received free shipping on a book purchase.	t	2023-06-03 23:25:25.168893	2023-06-03 23:25:25.168893
723	187	4	He paid for some books in advance.	f	2023-06-03 23:25:25.238975	2023-06-03 23:25:25.238975
724	188	1	To explain a problem	t	2023-06-03 23:25:25.298959	2023-06-03 23:25:25.298959
725	188	2	To ask for volunteers	f	2023-06-03 23:25:25.352766	2023-06-03 23:25:25.352766
726	188	3	To request payment	f	2023-06-03 23:25:25.399021	2023-06-03 23:25:25.399021
727	188	4	To promote a book	f	2023-06-03 23:25:25.450987	2023-06-03 23:25:25.450987
728	189	1	The deadline for submitting a project	f	2023-06-03 23:25:25.494981	2023-06-03 23:25:25.494981
729	189	2	The content of a book review	f	2023-06-03 23:25:25.542959	2023-06-03 23:25:25.542959
730	189	3	The time of a scheduled meeting	f	2023-06-03 23:25:25.590957	2023-06-03 23:25:25.590957
731	189	4	The display of some information	t	2023-06-03 23:25:25.687047	2023-06-03 23:25:25.687047
732	190	1	$17.60	t	2023-06-03 23:25:25.735451	2023-06-03 23:25:25.735451
733	190	2	$14.40	f	2023-06-03 23:25:25.784688	2023-06-03 23:25:25.784688
734	190	3	$16.00	f	2023-06-03 23:25:25.828618	2023-06-03 23:25:25.828618
735	190	4	$22.40	f	2023-06-03 23:25:25.8713	2023-06-03 23:25:25.8713
736	191	1	To report on the benefits of mixed-use buildings	f	2023-06-03 23:25:25.918964	2023-06-03 23:25:25.918964
737	191	2	To provide an update on a project	t	2023-06-03 23:25:25.965806	2023-06-03 23:25:25.965806
738	191	3	To encourage residents to apply for jobs	f	2023-06-03 23:25:26.009312	2023-06-03 23:25:26.009312
739	191	4	To announce a change in city policy	f	2023-06-03 23:25:26.071616	2023-06-03 23:25:26.071616
740	192	1	Its cost efficiency	f	2023-06-03 23:25:26.11977	2023-06-03 23:25:26.11977
741	192	2	Its compliance with environmental standards	f	2023-06-03 23:25:26.187782	2023-06-03 23:25:26.187782
742	192	3	The anticipated quality of the renovation work	t	2023-06-03 23:25:26.242536	2023-06-03 23:25:26.242536
743	192	4	The large amount of retail space	f	2023-06-03 23:25:26.312892	2023-06-03 23:25:26.312892
744	193	1	It received the approval it was seeking.	t	2023-06-03 23:25:26.356643	2023-06-03 23:25:26.356643
745	193	2	It has the only available office spaces for rent in Clanton.	f	2023-06-03 23:25:26.400524	2023-06-03 23:25:26.400524
746	193	3	It has moved its main office to the Anton Building.	f	2023-06-03 23:25:26.447158	2023-06-03 23:25:26.447158
747	193	4	It is a relatively new company.	f	2023-06-03 23:25:26.491963	2023-06-03 23:25:26.491963
748	194	1	The distance to the nearest train station.	f	2023-06-03 23:25:26.547462	2023-06-03 23:25:26.547462
749	194	2	The other occupants` types of business	f	2023-06-03 23:25:26.61535	2023-06-03 23:25:26.61535
750	194	3	The completion date of the renovation	f	2023-06-03 23:25:26.65773	2023-06-03 23:25:26.65773
751	194	4	The availability of employee parking	t	2023-06-03 23:25:26.701157	2023-06-03 23:25:26.701157
752	195	1	Unit 2B	f	2023-06-03 23:25:26.745591	2023-06-03 23:25:26.745591
753	195	2	Unit 2C	f	2023-06-03 23:25:26.789035	2023-06-03 23:25:26.789035
754	195	3	Unit 2D	f	2023-06-03 23:25:26.862533	2023-06-03 23:25:26.862533
755	195	4	Unit 2E	t	2023-06-03 23:25:26.909263	2023-06-03 23:25:26.909263
756	196	1	She has used DGC`s services before.	t	2023-06-03 23:25:26.958992	2023-06-03 23:25:26.958992
757	196	2	She teaches a course in boating safety.	f	2023-06-03 23:25:27.00892	2023-06-03 23:25:27.00892
758	196	3	She is a resident of Daneston.	f	2023-06-03 23:25:27.053498	2023-06-03 23:25:27.053498
759	196	4	She owns her own kayak.	f	2023-06-03 23:25:27.098207	2023-06-03 23:25:27.098207
760	197	1	Option 1	f	2023-06-03 23:25:27.141748	2023-06-03 23:25:27.141748
761	197	2	Option 2	f	2023-06-03 23:25:27.184493	2023-06-03 23:25:27.184493
762	197	3	Option 3	t	2023-06-03 23:25:27.229811	2023-06-03 23:25:27.229811
763	197	4	Option 4	f	2023-06-03 23:25:27.278974	2023-06-03 23:25:27.278974
764	198	1	$11	f	2023-06-03 23:25:27.322502	2023-06-03 23:25:27.322502
765	198	2	$13	t	2023-06-03 23:25:27.365358	2023-06-03 23:25:27.365358
766	198	3	$14	f	2023-06-03 23:25:27.407657	2023-06-03 23:25:27.407657
767	198	4	$15	f	2023-06-03 23:25:27.450278	2023-06-03 23:25:27.450278
768	199	1	It is open for business all year.	f	2023-06-03 23:25:27.49464	2023-06-03 23:25:27.49464
769	199	2	It may close for the day if the weather is bad.	f	2023-06-03 23:25:27.538217	2023-06-03 23:25:27.538217
770	199	3	It offers special rates for groups of ten or more.	t	2023-06-03 23:25:27.583266	2023-06-03 23:25:27.583266
771	199	4	It accepts reservations on its Web site.	f	2023-06-03 23:25:27.627015	2023-06-03 23:25:27.627015
772	200	1	They can fit three adults.	f	2023-06-03 23:25:27.67088	2023-06-03 23:25:27.67088
773	200	2	They can be rented overnight.	f	2023-06-03 23:25:27.716884	2023-06-03 23:25:27.716884
774	200	3	They are suitable for small children.	f	2023-06-03 23:25:27.768219	2023-06-03 23:25:27.768219
775	200	4	They are equipped with life jackets.	t	2023-06-03 23:25:27.813531	2023-06-03 23:25:27.813531
\.


--
-- Data for Name: comment; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.comment (comment_id, student_id, course_id, content, total_like, respond_id, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: course; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.course (course_id, name, image, level, charges, point_to_unlock, point_reward, quantity_rating, avg_rating, participants, price, discount, total_chapter, total_lesson, total_video_time, achieves, description, created_by, created_at, updated_at) FROM stdin;
11	Voltsillam	http://dummyimage.com/359x321.png/5fa2dd/ffffff	basic	t	7250	1867	0	0.00	0	1232695	59	0	0	0	Beam Radiation of Mouth using Neutron Capture	Beam Radiation of Mouth using Neutron Capture	5	2023-06-03 15:04:13.271339	2023-06-03 15:04:13.271339
12	Viva	http://dummyimage.com/321x290.png/5fa2dd/ffffff	basic	t	6195	1870	0	0.00	0	1692552	96	0	0	0	Remove Autol Sub from L Toe Phalanx Jt, Perc Endo	Removal of Autologous Tissue Substitute from Left Toe Phalangeal Joint, Percutaneous Endoscopic Approach	6	2023-06-03 15:04:13.313145	2023-06-03 15:04:13.313145
13	Ventosanzap	http://dummyimage.com/268x302.png/cc0000/ffffff	basic	f	9314	1946	0	0.00	0	1019512	46	0	0	0	Plain Radiography of L Salivary Gland using L Osm Contrast	Plain Radiography of Left Salivary Gland using Low Osmolar Contrast	1	2023-06-03 15:04:13.404847	2023-06-03 15:04:13.404847
14	Cardguard	http://dummyimage.com/313x293.png/ff4444/ffffff	basic	t	127	1446	0	0.00	0	289870	63	0	0	0	Destruction of Left Thyroid Gland Lobe, Open Approach	Destruction of Left Thyroid Gland Lobe, Open Approach	2	2023-06-03 15:04:13.464769	2023-06-03 15:04:13.464769
15	Voltsillam	http://dummyimage.com/285x364.png/5fa2dd/ffffff	advance	t	721	1109	0	0.00	0	652217	96	0	0	0	Repair Female Reproductive System in POC, Via Opening	Repair Female Reproductive System in Products of Conception, Via Natural or Artificial Opening	3	2023-06-03 15:04:13.506735	2023-06-03 15:04:13.506735
16	Cookley	http://dummyimage.com/391x348.png/5fa2dd/ffffff	advance	f	3110	1343	0	0.00	0	1297378	70	0	0	0	Beam Radiation of Uterus using Heavy Particles	Beam Radiation of Uterus using Heavy Particles (Protons,Ions)	4	2023-06-03 15:04:13.555495	2023-06-03 15:04:13.555495
17	Home Ing	http://dummyimage.com/358x341.png/5fa2dd/ffffff	advance	t	734	1162	0	0.00	0	1092888	46	0	0	0	Transfuse Autol Cord Bld Stem Cell in Periph Vein, Open	Transfusion of Autologous Cord Blood Stem Cells into Peripheral Vein, Open Approach	5	2023-06-03 15:04:13.595794	2023-06-03 15:04:13.595794
18	Flowdesk	http://dummyimage.com/261x380.png/ff4444/ffffff	advance	t	111	1206	0	0.00	0	1378284	63	0	0	0	Destruction of Thoracic Vertebral Joint, Perc Approach	Destruction of Thoracic Vertebral Joint, Percutaneous Approach	6	2023-06-03 15:04:13.64528	2023-06-03 15:04:13.64528
19	Wrapsafe	http://dummyimage.com/381x313.png/cc0000/ffffff	advance	f	8390	1830	0	0.00	0	293144	76	0	0	0	Restriction of Cystic Duct, Via Opening	Restriction of Cystic Duct, Via Natural or Artificial Opening	1	2023-06-03 15:04:13.746971	2023-06-03 15:04:13.746971
20	Gembucket	http://dummyimage.com/269x398.png/dddddd/000000	advance	t	873	1404	0	0.00	0	202693	67	0	0	0	Drainage of Right Colic Artery with Drain Dev, Open Approach	Drainage of Right Colic Artery with Drainage Device, Open Approach	2	2023-06-03 15:04:13.791118	2023-06-03 15:04:13.791118
21	Duobam	http://dummyimage.com/315x354.png/5fa2dd/ffffff	advance	f	9534	1912	0	0.00	0	475174	95	0	0	0	Bypass Right Renal Vein to Lower Vein, Open Approach	Bypass Right Renal Vein to Lower Vein, Open Approach	3	2023-06-03 15:04:13.832088	2023-06-03 15:04:13.832088
22	Zontrax	http://dummyimage.com/396x389.png/5fa2dd/ffffff	advance	f	9406	1359	0	0.00	0	1967492	10	0	0	0	Drain of R Humeral Shaft with Drain Dev, Perc Endo Approach	Drainage of Right Humeral Shaft with Drainage Device, Percutaneous Endoscopic Approach	4	2023-06-03 15:04:13.879133	2023-06-03 15:04:13.879133
23	Kanlam	http://dummyimage.com/261x263.png/ff4444/ffffff	advance	f	2587	1171	0	0.00	0	994163	21	0	0	0	Drainage of Sacral Nerve, Percutaneous Approach, Diagnostic	Drainage of Sacral Nerve, Percutaneous Approach, Diagnostic	5	2023-06-03 15:04:13.940168	2023-06-03 15:04:13.940168
24	Toughjoyfax	http://dummyimage.com/319x260.png/dddddd/000000	advance	f	5567	1069	0	0.00	0	835315	4	0	0	0	Revision of Infusion Device in Abdominal Wall, Open Approach	Revision of Infusion Device in Abdominal Wall, Open Approach	6	2023-06-03 15:04:13.993175	2023-06-03 15:04:13.993175
25	Opela	http://dummyimage.com/311x310.png/cc0000/ffffff	advance	t	2785	1424	0	0.00	0	1071143	2	0	0	0	Excision of Hymen, Via Natural or Artificial Opening, Diagn	Excision of Hymen, Via Natural or Artificial Opening, Diagnostic	1	2023-06-03 15:04:14.057085	2023-06-03 15:04:14.057085
26	Voltsillam	http://dummyimage.com/384x290.png/ff4444/ffffff	advance	f	2072	1633	0	0.00	0	1101596	74	0	0	0	Removal of Extralum Dev from Up Vein, Perc Endo Approach	Removal of Extraluminal Device from Upper Vein, Percutaneous Endoscopic Approach	2	2023-06-03 15:04:14.108347	2023-06-03 15:04:14.108347
27	Zathin	http://dummyimage.com/324x339.png/cc0000/ffffff	advance	t	7114	1285	0	0.00	0	950224	45	0	0	0	Bypass Sup Vena Cava to L Pulm Vn w Synth Sub, Perc Endo	Bypass Superior Vena Cava to Left Pulmonary Vein with Synthetic Substitute, Percutaneous Endoscopic Approach	3	2023-06-03 15:04:14.158484	2023-06-03 15:04:14.158484
7	Lotlux	http://dummyimage.com/378x351.png/5fa2dd/ffffff	basic	t	1090	1021	5	3.40	2	532008	92	10	30	0	Excision of Right Lower Lobe Bronchus, Via Opening, Diagn	Excision of Right Lower Lobe Bronchus, Via Natural or Artificial Opening, Diagnostic	1	2023-06-03 15:04:13.090301	2023-06-03 15:05:01.395272
4	Konklab	http://dummyimage.com/283x304.png/5fa2dd/ffffff	basic	t	5240	1372	6	2.17	1	1814315	26	10	30	0	Excision of Right Pulmonary Artery, Open Approach	Excision of Right Pulmonary Artery, Open Approach	4	2023-06-03 15:04:12.858791	2023-06-03 15:05:01.73741
9	It	http://dummyimage.com/387x279.png/5fa2dd/ffffff	basic	t	5145	1075	5	2.80	2	338827	46	10	30	0	LDR Brachytherapy of Pineal Body using Oth Isotope	Low Dose Rate (LDR) Brachytherapy of Pineal Body using Other Isotope	3	2023-06-03 15:04:13.178797	2023-06-03 15:05:01.634339
2	Toughjoyfax	http://dummyimage.com/357x297.png/dddddd/000000	basic	f	9365	1277	6	3.33	1	438727	43	10	30	0	Dilation of Abdominal Aorta, Bifurcation, Perc Approach	Dilation of Abdominal Aorta, Bifurcation, Percutaneous Approach	1	2023-06-03 15:04:12.764115	2023-06-03 15:05:01.859209
10	Toughjoyfax	http://dummyimage.com/281x254.png/ff4444/ffffff	basic	t	1728	1846	1	2.00	1	1222399	62	10	30	0	Drainage of Sciatic Nerve, Perc Endo Approach, Diagn	Drainage of Sciatic Nerve, Percutaneous Endoscopic Approach, Diagnostic	4	2023-06-03 15:04:13.229636	2023-06-03 15:04:59.151168
3	Matsoft	http://dummyimage.com/359x328.png/cc0000/ffffff	basic	f	1271	1365	6	3.17	2	1108446	15	10	30	0	Dilate Inf Mesent Art, Bifurc, w 4 Drug-elut, Open	             Dilation of Inferior Mesenteric Artery, Bifurcation, with Four or More Drug-eluting Intraluminal Devices, Open Approach	3	2023-06-03 15:04:12.813378	2023-06-03 15:05:01.796257
6	Gembucket	http://dummyimage.com/328x361.png/5fa2dd/ffffff	basic	t	6331	1565	5	2.00	1	941522	58	10	30	0	Bypass R Int Jugular Vein to Up Vein w Nonaut Sub, Perc Endo	Bypass Right Internal Jugular Vein to Upper Vein with Nonautologous Tissue Substitute, Percutaneous Endoscopic Approach	6	2023-06-03 15:04:12.976135	2023-06-03 15:05:01.33844
5	Gembucket	http://dummyimage.com/370x314.png/ff4444/ffffff	basic	t	3094	1088	5	3.20	2	1249682	60	10	30	0	Drainage of R Ext Jugular Vein with Drain Dev, Open Approach	Drainage of Right External Jugular Vein with Drainage Device, Open Approach	5	2023-06-03 15:04:12.907157	2023-06-03 15:05:01.293828
8	Sonsing	http://dummyimage.com/338x386.png/dddddd/000000	basic	t	2532	1656	5	3.40	1	613691	69	10	30	0	Destruction of Right Atrium, Perc Endo Approach	Destruction of Right Atrium, Percutaneous Endoscopic Approach	2	2023-06-03 15:04:13.137799	2023-06-03 15:05:01.538965
28	Cardify	http://dummyimage.com/398x399.png/ff4444/ffffff	advance	t	3514	1599	0	0.00	0	1804107	73	0	0	0	Extirpate of Matter from R Post Tib Art, Perc Endo Approach	Extirpation of Matter from Right Posterior Tibial Artery, Percutaneous Endoscopic Approach	4	2023-06-03 15:04:14.206202	2023-06-03 15:04:14.206202
29	Matsoft	http://dummyimage.com/294x278.png/ff4444/ffffff	advance	t	4348	1576	0	0.00	0	921195	61	0	0	0	Repair Right Foot Bursa and Ligament, Open Approach	Repair Right Foot Bursa and Ligament, Open Approach	5	2023-06-03 15:04:14.258721	2023-06-03 15:04:14.258721
30	Bamity	http://dummyimage.com/267x327.png/ff4444/ffffff	advance	t	7544	1215	0	0.00	0	227343	41	0	0	0	Change Brace on Neck	Change Brace on Neck	6	2023-06-03 15:04:14.307809	2023-06-03 15:04:14.307809
1	Sonsing	http://dummyimage.com/366x299.png/dddddd/000000	basic	f	9987	1597	6	3.00	2	1362476	10	10	30	0	Revision of Intraluminal Device in Lymph, Perc Endo Approach	Revision of Intraluminal Device in Lymphatic, Percutaneous Endoscopic Approach	2	2023-06-03 15:04:12.607957	2023-06-03 15:05:01.99912
\.


--
-- Data for Name: django_admin_log; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.django_admin_log (id, action_time, object_id, object_repr, action_flag, change_message, content_type_id, user_id) FROM stdin;
\.


--
-- Data for Name: django_content_type; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.django_content_type (id, app_label, model) FROM stdin;
1	admin	logentry
2	auth	permission
3	auth	group
4	contenttypes	contenttype
5	sessions	session
6	authentication	user
7	api	category
8	api	product
9	api	order
10	api	variation
11	api	orderdetail
12	api	review
13	api	address
14	api	paymentprovider
15	api	payment
16	api	cartitem
17	api	favoriteitem
18	api	voucher
19	api	usedvoucher
\.


--
-- Data for Name: django_migrations; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.django_migrations (id, app, name, applied) FROM stdin;
1	contenttypes	0001_initial	2023-06-21 02:38:56.775097+00
2	contenttypes	0002_remove_content_type_name	2023-06-21 02:38:56.794353+00
3	auth	0001_initial	2023-06-21 02:38:57.005548+00
4	auth	0002_alter_permission_name_max_length	2023-06-21 02:38:57.048168+00
5	auth	0003_alter_user_email_max_length	2023-06-21 02:38:57.071637+00
6	auth	0004_alter_user_username_opts	2023-06-21 02:38:57.084101+00
7	auth	0005_alter_user_last_login_null	2023-06-21 02:38:57.156785+00
8	auth	0006_require_contenttypes_0002	2023-06-21 02:38:57.170926+00
9	auth	0007_alter_validators_add_error_messages	2023-06-21 02:38:57.188656+00
10	auth	0008_alter_user_username_max_length	2023-06-21 02:38:57.204992+00
11	auth	0009_alter_user_last_name_max_length	2023-06-21 02:38:57.259848+00
12	auth	0010_alter_group_name_max_length	2023-06-21 02:38:57.293383+00
13	auth	0011_update_proxy_permissions	2023-06-21 02:38:57.311706+00
14	auth	0012_alter_user_first_name_max_length	2023-06-21 02:38:57.357752+00
15	authentication	0001_initial	2023-06-21 02:38:57.560982+00
16	admin	0001_initial	2023-06-21 02:38:57.660759+00
17	admin	0002_logentry_remove_auto_add	2023-06-21 02:38:57.67815+00
18	admin	0003_logentry_add_action_flag_choices	2023-06-21 02:38:57.795714+00
19	api	0001_initial	2023-06-21 02:38:57.854146+00
20	api	0002_alter_category_desc	2023-06-21 02:38:57.866306+00
21	api	0003_alter_product_desc	2023-06-21 02:38:57.934376+00
22	api	0004_order_variation_orderdetail	2023-06-21 02:38:58.205838+00
23	api	0005_alter_variation_product	2023-06-21 02:38:58.244324+00
24	api	0006_alter_orderdetail_order_remove_orderdetail_product_and_more	2023-06-21 02:38:58.440336+00
25	api	0007_product_reviews_count_alter_orderdetail_product	2023-06-21 02:38:58.48035+00
26	api	0008_review	2023-06-21 02:38:58.634289+00
27	api	0009_alter_category_options_alter_order_options_and_more	2023-06-21 02:38:58.718827+00
28	api	0010_variation_is_deleted	2023-06-21 02:38:58.752663+00
29	api	0011_product_avg_rating	2023-06-21 02:38:58.781291+00
30	api	0012_review_product	2023-06-21 02:38:58.953303+00
31	api	0013_alter_orderdetail_order	2023-06-21 02:38:59.037778+00
32	api	0014_alter_order_created_by	2023-06-21 02:38:59.07069+00
33	api	0015_alter_order_created_by_alter_review_created_by	2023-06-21 02:38:59.121058+00
34	api	0016_order_email_address	2023-06-21 02:38:59.220262+00
35	api	0017_paymentprovider_payment	2023-06-21 02:38:59.32517+00
36	api	0018_payment_created_by	2023-06-21 02:38:59.388439+00
37	api	0019_remove_payment_method	2023-06-21 02:38:59.434818+00
38	api	0020_alter_payment_created_by_cartitem	2023-06-21 02:38:59.54662+00
39	api	0021_alter_cartitem_qty	2023-06-21 02:38:59.582306+00
40	api	0022_favoriteitem	2023-06-21 02:38:59.69183+00
41	api	0023_category_is_deleted	2023-06-21 02:38:59.737187+00
42	api	0024_product_variations_count	2023-06-21 02:38:59.785385+00
43	api	0025_product_discount_alter_order_district_and_more	2023-06-21 02:39:00.096773+00
44	api	0026_voucher_order_shipping_date_order_voucher	2023-06-21 02:39:00.183865+00
45	api	0027_voucher_code	2023-06-21 02:39:00.199333+00
46	api	0028_alter_voucher_code	2023-06-21 02:39:00.27982+00
47	api	0029_alter_category_img_url_alter_payment_exp_and_more	2023-06-21 02:39:00.394577+00
48	api	0030_usedvoucher	2023-06-21 02:39:00.465714+00
49	api	0031_remove_favoriteitem_variation	2023-06-21 02:39:00.66432+00
50	api	0032_review_img_urls	2023-06-21 02:39:00.821836+00
51	api	0033_alter_review_img_urls	2023-06-21 02:39:00.872892+00
52	api	0034_alter_review_img_urls	2023-06-21 02:39:01.098561+00
53	api	0035_payment_number	2023-06-21 02:39:01.189975+00
54	api	0036_payment_cvc_alter_payment_number	2023-06-21 02:39:01.444517+00
55	api	0037_alter_order_total_alter_orderdetail_price_and_more	2023-06-21 02:39:01.948738+00
56	api	0038_product_composition_product_depth_product_height_and_more	2023-06-21 02:39:02.340905+00
57	api	0039_rename_composition_product_material	2023-06-21 02:39:02.451533+00
58	api	0040_voucher_inventory	2023-06-21 02:39:02.548814+00
59	api	0041_alter_product_avg_rating	2023-06-21 02:39:02.85102+00
60	authentication	0002_alter_user_email	2023-06-21 02:39:03.040047+00
61	authentication	0003_user_dob_user_full_name_user_gender_user_phone	2023-06-21 02:39:03.437644+00
62	authentication	0004_user_avatar	2023-06-21 02:39:03.63588+00
63	sessions	0001_initial	2023-06-21 02:39:03.934505+00
64	api	0042_alter_review_img_urls	2023-06-21 02:54:52.04337+00
65	api	0043_rename_depth_product_length	2023-06-24 01:11:05.907972+00
\.


--
-- Data for Name: django_session; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.django_session (session_key, session_data, expire_date) FROM stdin;
\.


--
-- Data for Name: exam; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.exam (exam_id, exam_series_id, name, total_part, total_question, total_comment, point_reward, nums_join, hashtag, is_full_explanation, audio, duration, file_download, created_at, updated_at) FROM stdin;
2	1	ETS TOEIC 2022 TEST 2	0	0	0	0	0	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:22.593536	2023-06-03 23:24:22.593536
3	1	ETS TOEIC 2022 TEST 3	0	0	0	0	0	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:22.702699	2023-06-03 23:24:22.702699
4	1	ETS TOEIC 2022 TEST 4	0	0	0	0	0	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:22.83595	2023-06-03 23:24:22.83595
5	1	ETS TOEIC 2022 TEST 5	0	0	0	0	0	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:22.934316	2023-06-03 23:24:22.934316
6	1	ETS TOEIC 2022 TEST 6	0	0	0	0	0	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:22.982101	2023-06-03 23:24:22.982101
7	1	ETS TOEIC 2022 TEST 7	0	0	0	0	0	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:23.025184	2023-06-03 23:24:23.025184
8	1	ETS TOEIC 2022 TEST 8	0	0	0	0	0	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:23.090789	2023-06-03 23:24:23.090789
9	1	ETS TOEIC 2022 TEST 9	0	0	0	0	0	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:23.139611	2023-06-03 23:24:23.139611
10	1	ETS TOEIC 2022 TEST 10	0	0	0	0	0	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:23.184504	2023-06-03 23:24:23.184504
11	2	ETS TOEIC 2022 TEST 1	0	0	0	0	0	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:23.227145	2023-06-03 23:24:23.227145
12	2	ETS TOEIC 2022 TEST 2	0	0	0	0	0	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:23.270308	2023-06-03 23:24:23.270308
1	1	ETS TOEIC 2022 TEST 1	7	200	0	0	1	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:22.538932	2023-06-03 23:25:33.356635
\.


--
-- Data for Name: exam_series; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.exam_series (exam_series_id, name, total_exam, public_date, author, created_by, created_at, updated_at) FROM stdin;
1	ETS 2022	10	2021-12-13	Educational Testing Service	1	2023-06-03 23:24:22.334961	2023-06-03 23:24:23.184504
2	ETS 2021	2	2020-12-13	Educational Testing Service	1	2023-06-03 23:24:22.391369	2023-06-03 23:24:23.270308
\.


--
-- Data for Name: exam_taking; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.exam_taking (exam_taking_id, exam_id, user_id, time_finished, nums_of_correct_qn, total_question, created_at, updated_at) FROM stdin;
1	1	1	6000	27	100	2023-06-03 23:25:33.356635	2023-06-03 23:25:33.356635
\.


--
-- Data for Name: flashcard; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.flashcard (fc_id, fc_set_id, word, meaning, type_of_word, pronounce, audio, example, note, image, created_by, created_at, updated_at) FROM stdin;
1	13	euismod	Acquired clawhand, left hand	id	Unspecified injury of flexor muscle, fascia and tendon of left index finger at wrist and hand level, sequela	\N	Drowning and submersion due to other accident to canoe or kayak	\N	\N	17	2023-06-03 15:05:27.708691	2023-06-03 15:05:27.708691
2	8	primis	Epiphora due to insufficient drainage	odio	Malignant poorly differentiated neuroendocrine tumors	\N	Corrosion of unspecified degree of multiple left fingers (nail), not including thumb	Displaced comminuted fracture of shaft of left femur, subsequent encounter for closed fracture with routine healing	http://dummyimage.com/178x100.png/cc0000/ffffff	12	2023-06-03 15:05:27.753927	2023-06-03 15:05:27.753927
3	19	semper	Strain of flexor muscle, fascia and tendon of right thumb at forearm level, subsequent encounter	faucibus	Exposure to other man-made environmental factors	\N	Poisoning by propionic acid derivatives, accidental (unintentional), sequela	\N	\N	14	2023-06-03 15:05:27.803698	2023-06-03 15:05:27.803698
4	17	purus	Other disorders of autonomic nervous system	ipsum	Nondisplaced fracture of trapezium [larger multangular], right wrist	\N	Subluxation of C0/C1 cervical vertebrae	\N	\N	6	2023-06-03 15:05:27.844146	2023-06-03 15:05:27.844146
5	6	eu	Other lymphoid leukemia	lobortis	Unspecified mood [affective] disorder	\N	War operations involving explosion of improvised explosive device [IED], civilian	\N	\N	20	2023-06-03 15:05:27.89168	2023-06-03 15:05:27.89168
6	17	ultrices	Displaced fracture of medial phalanx of unspecified finger, subsequent encounter for fracture with nonunion	vel	Drowning and submersion due to falling or jumping from crushed passenger ship	\N	Pedestrian injured in collision with other nonmotor vehicle in traffic accident	\N	\N	10	2023-06-03 15:05:27.941554	2023-06-03 15:05:27.941554
7	8	primis	Laceration of long flexor muscle, fascia and tendon of thumb at wrist and hand level	vestibulum	Superficial foreign body of unspecified hand, initial encounter	\N	Partial traumatic amputation at knee level, left lower leg	Accidental malfunction of paintball gun, sequela	http://dummyimage.com/219x100.png/cc0000/ffffff	19	2023-06-03 15:05:27.987649	2023-06-03 15:05:27.987649
8	15	nulla	Whooping cough, unspecified species	primis	Crushed between (nonpowered) inflatable craft and other watercraft or other object due to collision, subsequent encounter	\N	Moderate laceration of left kidney	\N	\N	5	2023-06-03 15:05:28.033176	2023-06-03 15:05:28.033176
9	19	purus	Corrosion of third degree of multiple sites of right shoulder and upper limb, except wrist and hand, initial encounter	habitasse	Dislocation of interphalangeal joint of left lesser toe(s), subsequent encounter	\N	Basal cell carcinoma of skin of right ear and external auricular canal	\N	\N	17	2023-06-03 15:05:28.094214	2023-06-03 15:05:28.094214
10	12	cras	Chronic meningococcemia	felis	Fibrosis due to nervous system prosthetic devices, implants and grafts	\N	Other displaced fracture of base of first metacarpal bone, right hand, initial encounter for closed fracture	\N	\N	4	2023-06-03 15:05:28.143705	2023-06-03 15:05:28.143705
11	11	ac	Fracture of hook process of hamate [unciform] bone	cubilia	Myositis ossificans progressiva, right lower leg	\N	Poisoning by diagnostic agents, intentional self-harm, subsequent encounter	\N	\N	19	2023-06-03 15:05:28.18786	2023-06-03 15:05:28.18786
12	7	erat	Traumatic spondylopathy, thoracolumbar region	cras	Displaced fracture of medial malleolus of right tibia, sequela	\N	Displaced fracture of coracoid process, right shoulder, subsequent encounter for fracture with malunion	\N	\N	6	2023-06-03 15:05:28.230227	2023-06-03 15:05:28.230227
13	8	lacinia	Nondisplaced fracture of posterior process of left talus	bibendum	Unspecified injury of anterior tibial artery, right leg, initial encounter	\N	Abrasion of fingers	\N	\N	3	2023-06-03 15:05:28.273356	2023-06-03 15:05:28.273356
14	5	erat	Multiple valve diseases	libero	Maternal care for Anti-A sensitization, unspecified trimester, fetus 4	\N	Toxic effect of other insecticides, undetermined, subsequent encounter	\N	\N	3	2023-06-03 15:05:28.31698	2023-06-03 15:05:28.31698
15	5	et	Displaced fracture of unspecified radial styloid process, subsequent encounter for open fracture type I or II with routine healing	amet	Lateral dislocation of proximal end of tibia, left knee, subsequent encounter	\N	Microgenia	\N	\N	9	2023-06-03 15:05:28.360215	2023-06-03 15:05:28.360215
16	19	vestibulum	Atherosclerosis of native arteries of extremities with rest pain, bilateral legs	nisi	Other voice and resonance disorders	\N	Displaced fracture of anterior process of right calcaneus, subsequent encounter for fracture with malunion	\N	\N	13	2023-06-03 15:05:28.403302	2023-06-03 15:05:28.403302
17	8	volutpat	Underdosing and nonadministration of necessary drug, medicament or biological substance	lacinia	Other secondary gout, unspecified elbow	\N	Nondisplaced fracture of lateral malleolus of left fibula, initial encounter for open fracture type IIIA, IIIB, or IIIC	\N	\N	11	2023-06-03 15:05:28.447673	2023-06-03 15:05:28.447673
18	11	quam	Displaced longitudinal fracture of unspecified patella, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	sit	Unspecified intracapsular fracture of unspecified femur, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with delayed healing	\N	Displaced subtrochanteric fracture of right femur, subsequent encounter for open fracture type I or II with malunion	\N	\N	19	2023-06-03 15:05:28.498299	2023-06-03 15:05:28.498299
19	19	nonummy	Laceration of extensor muscle, fascia and tendon of right ring finger at wrist and hand level, sequela	feugiat	Unspecified acute lower respiratory infection	\N	Hemorrhage due to cardiac prosthetic devices, implants and grafts, initial encounter	\N	\N	2	2023-06-03 15:05:28.542955	2023-06-03 15:05:28.542955
20	20	tincidunt	Cerebral infarction due to thrombosis of right anterior cerebral artery	faucibus	Monoplegia of upper limb following nontraumatic intracerebral hemorrhage affecting right non-dominant side	\N	Gastric ulcer, unspecified as acute or chronic, without hemorrhage or perforation	\N	\N	7	2023-06-03 15:05:28.589088	2023-06-03 15:05:28.589088
21	10	nulla	Maternal care for other (suspected) fetal abnormality and damage, fetus 2	orci	Toxic effect of ketones, undetermined, initial encounter	\N	Nondisplaced spiral fracture of shaft of unspecified fibula, initial encounter for closed fracture	\N	\N	11	2023-06-03 15:05:28.634707	2023-06-03 15:05:28.634707
22	10	etiam	Stress fracture, right ankle	sagittis	Occupational exposure to environmental tobacco smoke	\N	Open bite of right lesser toe(s) without damage to nail, subsequent encounter	\N	\N	2	2023-06-03 15:05:28.685	2023-06-03 15:05:28.685
23	19	elementum	Displaced oblique fracture of shaft of left tibia, sequela	primis	Laceration with foreign body, left knee, subsequent encounter	\N	Nontraumatic compartment syndrome of right upper extremity	\N	\N	1	2023-06-03 15:05:28.742547	2023-06-03 15:05:28.742547
24	9	non	Other fish poisoning, assault, subsequent encounter	vulputate	Other mechanical complication of other vascular grafts	\N	Unspecified injury of unspecified muscle, fascia and tendon at wrist and hand level, unspecified hand, sequela	\N	\N	18	2023-06-03 15:05:28.790274	2023-06-03 15:05:28.790274
25	10	leo	Contusion of left ear, sequela	luctus	Biliary cirrhosis, unspecified	\N	Generalized rebound abdominal tenderness	\N	\N	10	2023-06-03 15:05:28.835846	2023-06-03 15:05:28.835846
26	5	nonummy	Postauricular fistula, unspecified ear	luctus	Trochanteric bursitis, unspecified hip	\N	Other displaced fracture of lower end of right humerus, subsequent encounter for fracture with nonunion	\N	\N	8	2023-06-03 15:05:28.895876	2023-06-03 15:05:28.895876
27	15	luctus	Poisoning by immunoglobulin, assault, sequela	dapibus	Puncture wound of abdominal wall with foreign body, right upper quadrant without penetration into peritoneal cavity, subsequent encounter	\N	Person on outside of ambulance or fire engine injured in nontraffic accident	\N	\N	8	2023-06-03 15:05:28.942772	2023-06-03 15:05:28.942772
28	7	integer	Anterior displaced fracture of sternal end of left clavicle, subsequent encounter for fracture with routine healing	in	Puncture wound without foreign body of left upper arm	\N	Diffuse follicle center lymphoma, intrathoracic lymph nodes	\N	\N	11	2023-06-03 15:05:28.98719	2023-06-03 15:05:28.98719
29	6	magna	Strain of muscle(s) and tendon(s) of peroneal muscle group at lower leg level, unspecified leg	ullamcorper	Underdosing of antihyperlipidemic and antiarteriosclerotic drugs, subsequent encounter	\N	Other injury of colon	\N	\N	6	2023-06-03 15:05:29.028671	2023-06-03 15:05:29.028671
30	19	fusce	Displaced fracture of neck of left talus, subsequent encounter for fracture with routine healing	aliquam	Fall on same level due to ice and snow, sequela	\N	Fracture of angle of left mandible, initial encounter for open fracture	\N	\N	20	2023-06-03 15:05:29.073467	2023-06-03 15:05:29.073467
31	15	id	Other reduction defects of lower limb	in	Fused toes, bilateral	\N	Drowning and submersion due to being washed overboard from water-skis, initial encounter	Adverse effect of other synthetic narcotics, subsequent encounter	http://dummyimage.com/168x100.png/dddddd/000000	17	2023-06-03 15:05:29.118475	2023-06-03 15:05:29.118475
32	14	ipsum	Monoplegia of upper limb following other cerebrovascular disease affecting unspecified side	nulla	Nondisplaced Maisonneuve's fracture of right leg, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	\N	Adult sexual abuse, suspected, initial encounter	\N	\N	5	2023-06-03 15:05:29.169041	2023-06-03 15:05:29.169041
33	8	quis	Primary osteoarthritis, right hand	mattis	Coma scale, best motor response, abnormal, in the field [EMT or ambulance]	\N	Diseases of the skin and subcutaneous tissue complicating pregnancy, unspecified trimester	\N	\N	20	2023-06-03 15:05:29.22186	2023-06-03 15:05:29.22186
34	9	amet	Other specified joint disorders, right hand	sapien	Discoid lupus erythematosus of unspecified eye, unspecified eyelid	\N	Abnormal innervation syndrome left eye, unspecified eyelid	\N	\N	17	2023-06-03 15:05:29.27097	2023-06-03 15:05:29.27097
35	12	in	Incomplete lesion of L5 level of lumbar spinal cord, subsequent encounter	in	Nonadministration of surgical and medical care	\N	Struck by raccoon, subsequent encounter	\N	\N	2	2023-06-03 15:05:29.315819	2023-06-03 15:05:29.315819
36	6	ultrices	Other otosclerosis	maecenas	Superficial foreign body of lower back and pelvis	\N	External constriction of unspecified upper arm, sequela	\N	\N	11	2023-06-03 15:05:29.362134	2023-06-03 15:05:29.362134
37	15	in	Toxic effect of ingested berries, intentional self-harm, initial encounter	in	Idiopathic gout, left wrist	\N	Poisoning by angiotensin-converting-enzyme inhibitors, assault, initial encounter	\N	\N	1	2023-06-03 15:05:29.421342	2023-06-03 15:05:29.421342
38	15	tristique	Papyraceous fetus, first trimester, other fetus	praesent	Car passenger injured in collision with pedestrian or animal in nontraffic accident, sequela	\N	Poisoning by antitussives, assault	\N	\N	6	2023-06-03 15:05:29.465291	2023-06-03 15:05:29.465291
39	16	lacinia	Other specified injury of vein at forearm level, right arm, sequela	vulputate	Immersion foot, left foot, subsequent encounter	\N	Mixed conductive and sensorineural hearing loss, unspecified	\N	\N	12	2023-06-03 15:05:29.510161	2023-06-03 15:05:29.510161
40	10	at	Corrosion of second degree of left shoulder, initial encounter	sodales	Poisoning by unspecified general anesthetics, accidental (unintentional)	\N	Encounter for fitting and adjustment of other gastrointestinal appliance and device	\N	\N	8	2023-06-03 15:05:29.554853	2023-06-03 15:05:29.554853
41	19	magna	Other nondisplaced fracture of lower end of unspecified humerus, subsequent encounter for fracture with routine healing	vel	Salter-Harris Type II physeal fracture of lower end of humerus, right arm, subsequent encounter for fracture with routine healing	\N	Poisoning by thrombolytic drug, undetermined, subsequent encounter	\N	\N	2	2023-06-03 15:05:29.613464	2023-06-03 15:05:29.613464
42	10	aliquam	Nondisplaced fracture of olecranon process with intraarticular extension of right ulna, subsequent encounter for open fracture type I or II with routine healing	lorem	Lymphocyte-rich Hodgkin lymphoma, intra-abdominal lymph nodes	\N	Concussion	\N	\N	2	2023-06-03 15:05:29.668276	2023-06-03 15:05:29.668276
43	10	dui	Unspecified motorcycle rider injured in collision with other motor vehicles in nontraffic accident	elementum	Burn of first degree of chest wall, initial encounter	\N	Abrasion of abdominal wall	\N	\N	9	2023-06-03 15:05:29.71711	2023-06-03 15:05:29.71711
44	7	vel	Toxic effect of fusel oil, intentional self-harm, sequela	tempor	Adverse effect of other vaccines and biological substances, subsequent encounter	\N	Blister (nonthermal) of right hand, subsequent encounter	\N	\N	8	2023-06-03 15:05:29.766965	2023-06-03 15:05:29.766965
45	6	vitae	Person on outside of bus injured in collision with pedestrian or animal in nontraffic accident, subsequent encounter	ornare	Other irregular eye movements	\N	Stress fracture, hip, unspecified, subsequent encounter for fracture with malunion	\N	\N	3	2023-06-03 15:05:29.818948	2023-06-03 15:05:29.818948
46	11	donec	Syndrome of inappropriate secretion of antidiuretic hormone	odio	Unspecified soft tissue disorder related to use, overuse and pressure, right shoulder	\N	Conjunctivochalasis	\N	\N	19	2023-06-03 15:05:29.869726	2023-06-03 15:05:29.869726
47	1	phasellus	Unspecified injury of other blood vessels at wrist and hand level of right arm, subsequent encounter	habitasse	Spontaneous rupture of flexor tendons, unspecified upper arm	\N	Person on outside of bus injured in collision with heavy transport vehicle or bus in traffic accident	\N	\N	4	2023-06-03 15:05:29.916933	2023-06-03 15:05:29.916933
48	14	quisque	Pilonidal cyst and sinus	ultrices	Paralytic ptosis of bilateral eyelids	\N	Nondisplaced oblique fracture of shaft of left femur, initial encounter for open fracture type IIIA, IIIB, or IIIC	\N	\N	18	2023-06-03 15:05:29.987962	2023-06-03 15:05:29.987962
49	8	sed	Unspecified injury of femoral artery, left leg, subsequent encounter	auctor	Nondisplaced fracture of second metatarsal bone, unspecified foot, subsequent encounter for fracture with routine healing	\N	Puncture wound with foreign body of left upper arm, sequela	\N	\N	20	2023-06-03 15:05:30.032022	2023-06-03 15:05:30.032022
50	17	vel	Laceration with foreign body of abdominal wall, unspecified quadrant with penetration into peritoneal cavity, subsequent encounter	integer	Left bundle-branch block, unspecified	\N	Personal history of malignant neoplasm of bone and soft tissue	\N	\N	2	2023-06-03 15:05:30.079214	2023-06-03 15:05:30.079214
51	15	eros	Displaced fracture of lateral condyle of right femur, subsequent encounter for open fracture type I or II with routine healing	suscipit	Nondisplaced fracture of right tibial tuberosity, subsequent encounter for closed fracture with routine healing	\N	Hemangioma unspecified site	\N	\N	15	2023-06-03 15:05:30.128157	2023-06-03 15:05:30.128157
52	2	consequat	Nondisplaced osteochondral fracture of right patella, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	ultrices	Age-related osteoporosis with current pathological fracture, right hand, sequela	\N	Poisoning by unspecified primarily systemic and hematological agent, intentional self-harm, initial encounter	\N	\N	19	2023-06-03 15:05:30.171102	2023-06-03 15:05:30.171102
53	20	tellus	Adverse effect of drugs affecting uric acid metabolism	eu	Lead-induced gout, hand	\N	Anterior cord syndrome at C3 level of cervical spinal cord, subsequent encounter	\N	\N	11	2023-06-03 15:05:30.221255	2023-06-03 15:05:30.221255
54	6	mus	Laceration with foreign body of right cheek and temporomandibular area, sequela	hac	Coma scale, best verbal response, confused conversation, unspecified time	\N	Carcinoma in situ of other female genital organs	\N	\N	13	2023-06-03 15:05:30.268046	2023-06-03 15:05:30.268046
55	8	at	Bipolar disorder, unspecified	tempor	LeFort II fracture, sequela	\N	Intermittent exophthalmos, bilateral	\N	\N	18	2023-06-03 15:05:30.31215	2023-06-03 15:05:30.31215
56	16	odio	Unspecified sprain of unspecified great toe, subsequent encounter	laoreet	Burn of unspecified degree of left palm, initial encounter	\N	Toxic effect of carbon monoxide from utility gas, assault, initial encounter	\N	\N	16	2023-06-03 15:05:30.366985	2023-06-03 15:05:30.366985
57	1	donec	Subluxation of metacarpophalangeal joint of left middle finger, sequela	ornare	Deformity of bilateral orbits due to trauma or surgery	\N	Salter-Harris Type II physeal fracture of phalanx of left toe, subsequent encounter for fracture with malunion	\N	\N	7	2023-06-03 15:05:30.414702	2023-06-03 15:05:30.414702
58	1	eu	Displaced fracture of base of unspecified metacarpal bone, subsequent encounter for fracture with routine healing	aliquam	Salter-Harris Type I physeal fracture of upper end of humerus, unspecified arm, subsequent encounter for fracture with routine healing	\N	Encounter for change or removal of surgical wound dressing	\N	\N	4	2023-06-03 15:05:30.467448	2023-06-03 15:05:30.467448
59	6	sollicitudin	Primary open-angle glaucoma, bilateral, severe stage	diam	Other specified injuries of vocal cord, subsequent encounter	\N	Other injury of extensor muscle, fascia and tendon of left ring finger at wrist and hand level, sequela	\N	\N	20	2023-06-03 15:05:30.515334	2023-06-03 15:05:30.515334
60	4	eu	Diverticulosis of small intestine without perforation or abscess without bleeding	venenatis	Other specified injury of left innominate or subclavian vein, sequela	\N	Allescheriasis	\N	\N	5	2023-06-03 15:05:30.579072	2023-06-03 15:05:30.579072
61	1	nulla	Nephrotic syndrome with minor glomerular abnormality	ligula	Chronic multifocal osteomyelitis, unspecified hand	\N	Calcific tendinitis, lower leg	\N	\N	4	2023-06-03 15:05:30.655536	2023-06-03 15:05:30.655536
62	12	volutpat	Salter-Harris Type I physeal fracture of lower end of ulna, right arm, subsequent encounter for fracture with delayed healing	cubilia	Displaced spiral fracture of shaft of radius, unspecified arm, subsequent encounter for open fracture type I or II with delayed healing	\N	Influenza due to other identified influenza virus with gastrointestinal manifestations	\N	\N	3	2023-06-03 15:05:30.728126	2023-06-03 15:05:30.728126
63	20	diam	Superficial foreign body of other specified part of neck, subsequent encounter	suspendisse	Unspecified injury of unspecified blood vessel at forearm level, right arm	\N	Nondisplaced fracture of shaft of fifth metacarpal bone, left hand, subsequent encounter for fracture with nonunion	\N	\N	9	2023-06-03 15:05:30.806442	2023-06-03 15:05:30.806442
64	1	vulputate	Toxic effect of other specified inorganic substances, assault, subsequent encounter	eget	Hairy cell leukemia not having achieved remission	\N	Nondisplaced fracture of epiphysis (separation) (upper) of right femur, subsequent encounter for open fracture type I or II with nonunion	\N	\N	4	2023-06-03 15:05:30.875105	2023-06-03 15:05:30.875105
65	12	vestibulum	Preterm labor second trimester with preterm delivery third trimester	amet	Complete lesion of L5 level of lumbar spinal cord, sequela	\N	Hypertrophy of bone, ulna and radius	\N	\N	1	2023-06-03 15:05:30.93454	2023-06-03 15:05:30.93454
66	3	etiam	Unspecified fracture of unspecified lower leg, initial encounter for closed fracture	ultrices	Person on outside of pick-up truck or van injured in collision with pedal cycle in nontraffic accident	\N	Subluxation of unspecified interphalangeal joint of right thumb, subsequent encounter	\N	\N	13	2023-06-03 15:05:31.034333	2023-06-03 15:05:31.034333
67	13	lacus	Type 1 diabetes mellitus with mild nonproliferative diabetic retinopathy	condimentum	Posterior synechiae (iris), left eye	\N	Abrasion, right lower leg, sequela	Nondisplaced fracture of neck of fifth metacarpal bone, left hand, subsequent encounter for fracture with nonunion	http://dummyimage.com/106x100.png/5fa2dd/ffffff	17	2023-06-03 15:05:31.13898	2023-06-03 15:05:31.13898
68	9	ut	Burn of unspecified degree of multiple sites of right lower limb, except ankle and foot	massa	Toxic effect of venom of other Australian snake, intentional self-harm	\N	Basal cell carcinoma of skin of other part of trunk	\N	\N	2	2023-06-03 15:05:31.234326	2023-06-03 15:05:31.234326
69	13	sociis	Other infective (teno)synovitis, right wrist	vel	Monoplegia of upper limb following cerebral infarction affecting unspecified side	\N	Choroidal detachment	Nondisplaced fracture of proximal phalanx of right little finger, subsequent encounter for fracture with delayed healing	http://dummyimage.com/209x100.png/cc0000/ffffff	3	2023-06-03 15:05:31.279296	2023-06-03 15:05:31.279296
70	15	phasellus	Eversion of bilateral lacrimal punctum	nibh	Other intraarticular fracture of lower end of right radius, subsequent encounter for closed fracture with delayed healing	\N	Struck by turtle	\N	\N	20	2023-06-03 15:05:31.33895	2023-06-03 15:05:31.33895
71	10	nisl	Other nondisplaced fracture of base of first metacarpal bone, right hand, subsequent encounter for fracture with malunion	nulla	Corrosion of second degree of shoulder and upper limb, except wrist and hand, unspecified site, initial encounter	\N	Nondisplaced spiral fracture of shaft of ulna, unspecified arm, subsequent encounter for open fracture type I or II with malunion	\N	\N	11	2023-06-03 15:05:31.388827	2023-06-03 15:05:31.388827
72	16	praesent	Other calcification of muscle, hand	in	Jumping or diving from boat striking water surface causing drowning and submersion, subsequent encounter	\N	Passenger in pick-up truck or van injured in collision with unspecified motor vehicles in nontraffic accident, initial encounter	\N	\N	9	2023-06-03 15:05:31.433371	2023-06-03 15:05:31.433371
73	13	a	Displaced segmental fracture of shaft of left femur, subsequent encounter for closed fracture with malunion	dapibus	Other complications of anesthesia during pregnancy	\N	Other incomplete lesion at unspecified level of cervical spinal cord, subsequent encounter	Legal intervention involving other gas, bystander injured, initial encounter	http://dummyimage.com/170x100.png/cc0000/ffffff	11	2023-06-03 15:05:31.477614	2023-06-03 15:05:31.477614
74	4	mollis	Accidental scratch by another person, sequela	ut	Injury of bronchus	\N	Migraine, unspecified, intractable, with status migrainosus	Military operations involving destruction of aircraft due to enemy fire or explosives, civilian, sequela	http://dummyimage.com/169x100.png/dddddd/000000	16	2023-06-03 15:05:31.525302	2023-06-03 15:05:31.525302
75	20	lacinia	Nondisplaced comminuted fracture of shaft of left tibia, sequela	pulvinar	Drug-induced chronic gout, left ankle and foot, with tophus (tophi)	\N	Supervision of pregnancy with history of ectopic pregnancy, second trimester	\N	\N	9	2023-06-03 15:05:31.583818	2023-06-03 15:05:31.583818
76	15	id	Term delivery with preterm labor, second trimester	posuere	Nondisplaced fracture of neck of unspecified talus, initial encounter for closed fracture	\N	Nondisplaced fracture of proximal phalanx of right little finger, initial encounter for open fracture	\N	\N	3	2023-06-03 15:05:31.625576	2023-06-03 15:05:31.625576
77	3	erat	Superficial foreign body, left thigh	aliquet	Underdosing of other drugs acting on muscles, subsequent encounter	\N	Other specified injury of left vertebral artery, sequela	\N	\N	8	2023-06-03 15:05:31.734327	2023-06-03 15:05:31.734327
78	6	vivamus	Contact with nonvenomous frogs, sequela	magna	Labyrinthine fistula, bilateral	\N	Unspecified sprain of left great toe, initial encounter	Unspecified injury at C2 level of cervical spinal cord, subsequent encounter	http://dummyimage.com/126x100.png/cc0000/ffffff	8	2023-06-03 15:05:31.784966	2023-06-03 15:05:31.784966
79	19	turpis	Other air transport accidents, not elsewhere classified	maecenas	Nondisplaced fracture of posterior wall of right acetabulum, initial encounter for open fracture	\N	Blepharochalasis left eye, unspecified eyelid	\N	\N	7	2023-06-03 15:05:31.833705	2023-06-03 15:05:31.833705
80	8	pretium	Burn of unspecified degree of unspecified ear [any part, except ear drum], initial encounter	sagittis	Presence of other devices	\N	Other fracture of T11-T12 vertebra, subsequent encounter for fracture with routine healing	\N	\N	18	2023-06-03 15:05:31.877629	2023-06-03 15:05:31.877629
81	12	fusce	Major laceration of right pulmonary blood vessels	rutrum	Crushing injury of unspecified foot, sequela	\N	Deformity of finger(s)	\N	\N	15	2023-06-03 15:05:31.921379	2023-06-03 15:05:31.921379
82	5	sapien	Hereditary factor XI deficiency	nulla	Unspecified open wound of unspecified finger without damage to nail, sequela	\N	Burn of third degree of left ankle	\N	\N	3	2023-06-03 15:05:31.984297	2023-06-03 15:05:31.984297
83	4	sagittis	Snow-skier colliding with stationary object, subsequent encounter	nibh	Sprain of interphalangeal joint of right great toe, subsequent encounter	\N	Other fracture of upper end of left tibia, subsequent encounter for closed fracture with nonunion	\N	\N	11	2023-06-03 15:05:32.026684	2023-06-03 15:05:32.026684
84	2	vestibulum	Nondisplaced fracture of medial condyle of unspecified tibia, subsequent encounter for closed fracture with malunion	eleifend	Fracture of nasal bones, initial encounter for open fracture	\N	Corrosion of second degree of multiple sites of right shoulder and upper limb, except wrist and hand, subsequent encounter	\N	\N	14	2023-06-03 15:05:32.095001	2023-06-03 15:05:32.095001
85	3	nisi	Injury to rider of non-recreational watercraft being pulled behind other watercraft	sapien	Assault by being hit or run over by motor vehicle, subsequent encounter	\N	Adverse effect of other drug primarily affecting the autonomic nervous system, subsequent encounter	\N	\N	12	2023-06-03 15:05:32.155065	2023-06-03 15:05:32.155065
86	12	sapien	Non-pressure chronic ulcer of right thigh with necrosis of bone	sit	Minor laceration of left internal jugular vein, initial encounter	\N	Open bite of vagina and vulva, subsequent encounter	\N	\N	20	2023-06-03 15:05:32.275889	2023-06-03 15:05:32.275889
87	8	in	Superficial foreign body of vagina and vulva	mi	Driver injured in collision with other motor vehicles in nontraffic accident, subsequent encounter	\N	Hallucinations, unspecified	\N	\N	8	2023-06-03 15:05:32.322757	2023-06-03 15:05:32.322757
88	19	volutpat	Late congenital syphilitic chorioretinitis	tellus	Unspecified fracture of shaft of unspecified ulna, initial encounter for open fracture type I or II	\N	Ganglion, left shoulder	\N	\N	12	2023-06-03 15:05:32.434325	2023-06-03 15:05:32.434325
89	4	orci	Other specified injury of anterior tibial artery, right leg, subsequent encounter	nulla	Underdosing of emollients, demulcents and protectants	\N	Spontaneous rupture of flexor tendons, unspecified site	\N	\N	8	2023-06-03 15:05:32.534391	2023-06-03 15:05:32.534391
90	20	libero	Conduction disorder, unspecified	nisi	Passenger on bus injured in collision with two- or three-wheeled motor vehicle in nontraffic accident, initial encounter	\N	Other fracture of upper end of unspecified tibia, subsequent encounter for closed fracture with routine healing	\N	\N	18	2023-06-03 15:05:32.634327	2023-06-03 15:05:32.634327
91	14	quam	Other fracture of lower end of right femur, subsequent encounter for open fracture type I or II with nonunion	praesent	Corrosion of unspecified degree of elbow	\N	Contusion of unspecified finger with damage to nail, initial encounter	\N	\N	16	2023-06-03 15:05:32.734391	2023-06-03 15:05:32.734391
92	19	nullam	Superficial foreign body of right back wall of thorax	volutpat	Postthrombotic syndrome with other complications of left lower extremity	\N	Other juvenile arthritis, right ankle and foot	Unspecified open wound of unspecified part of thorax	http://dummyimage.com/113x100.png/5fa2dd/ffffff	20	2023-06-03 15:05:32.78018	2023-06-03 15:05:32.78018
93	16	semper	Familial chondrocalcinosis, left shoulder	amet	Adverse effect of other antacids and anti-gastric-secretion drugs	\N	Infection and inflammatory reaction due to implanted electronic neurostimulator of peripheral nerve, electrode (lead), subsequent encounter	\N	\N	5	2023-06-03 15:05:32.823034	2023-06-03 15:05:32.823034
94	10	luctus	Preparatory care for renal dialysis	ligula	Crushing injury of unspecified external genital organs, female, sequela	\N	Unspecified injury of unspecified blood vessel at forearm level, unspecified arm, initial encounter	\N	\N	6	2023-06-03 15:05:32.935204	2023-06-03 15:05:32.935204
95	1	vestibulum	Phantom limb syndrome with pain	posuere	Nondisplaced fracture of unspecified ulna styloid process, subsequent encounter for closed fracture with delayed healing	\N	Other fracture of left lower leg, initial encounter for open fracture type I or II	\N	\N	10	2023-06-03 15:05:33.034336	2023-06-03 15:05:33.034336
96	18	vulputate	Disorders of the eye following cataract surgery	consectetuer	Displaced fracture of body of scapula, left shoulder, subsequent encounter for fracture with delayed healing	\N	Unspecified nondisplaced fracture of first cervical vertebra, subsequent encounter for fracture with nonunion	\N	\N	6	2023-06-03 15:05:33.138981	2023-06-03 15:05:33.138981
97	15	cras	Displaced oblique fracture of shaft of left tibia, initial encounter for closed fracture	amet	Displaced transverse fracture of shaft of humerus, right arm, initial encounter for open fracture	\N	Unspecified injury of other specified muscles, fascia and tendons at thigh level, right thigh, initial encounter	\N	\N	11	2023-06-03 15:05:33.234665	2023-06-03 15:05:33.234665
98	18	amet	Other disorders of pancreatic internal secretion	sed	Motor neuron disease	\N	Burn of third degree of ankle	Injury of unspecified nerve at wrist and hand level of right arm, sequela	http://dummyimage.com/242x100.png/cc0000/ffffff	11	2023-06-03 15:05:33.293665	2023-06-03 15:05:33.293665
99	14	sed	Passenger in heavy transport vehicle injured in collision with heavy transport vehicle or bus in nontraffic accident, subsequent encounter	lorem	Nondisplaced fracture of lower epiphysis (separation) of right femur, subsequent encounter for closed fracture with nonunion	\N	Displaced fracture of medial phalanx of unspecified finger, subsequent encounter for fracture with routine healing	Unspecified nondisplaced fracture of surgical neck of right humerus	http://dummyimage.com/171x100.png/ff4444/ffffff	14	2023-06-03 15:05:33.342666	2023-06-03 15:05:33.342666
100	13	odio	Laceration of other blood vessels at lower leg level, left leg	in	Subluxation of distal end of right ulna, initial encounter	\N	Other specified injury of femoral vein at hip and thigh level, right leg, sequela	Pregnancy related exhaustion and fatigue, unspecified trimester	http://dummyimage.com/243x100.png/5fa2dd/ffffff	4	2023-06-03 15:05:33.386739	2023-06-03 15:05:33.386739
101	2	placerat	Other osteoporosis with current pathological fracture, unspecified femur	accumsan	Sprain of interphalangeal joint of right ring finger, sequela	\N	Poisoning by enzymes, assault, sequela	\N	\N	11	2023-06-03 15:05:33.426802	2023-06-03 15:05:33.426802
102	14	pellentesque	Displacement of esophageal anti-reflux device	neque	Glaucoma secondary to other eye disorders, right eye, mild stage	\N	Unspecified early complication of trauma, subsequent encounter	\N	\N	9	2023-06-03 15:05:33.471197	2023-06-03 15:05:33.471197
103	7	aliquam	Atherosclerosis of nonbiological bypass graft(s) of the extremities with gangrene	in	Retinal detachment with retinal dialysis, right eye	\N	Nondisplaced fracture of left radial styloid process, subsequent encounter for closed fracture with delayed healing	\N	\N	2	2023-06-03 15:05:33.521867	2023-06-03 15:05:33.521867
104	18	nulla	Traumatic compartment syndrome of unspecified upper extremity, initial encounter	molestie	Military operations involving intentional restriction of air and airway, civilian	\N	Nondisplaced oblique fracture of shaft of unspecified femur, initial encounter for open fracture type I or II	\N	\N	12	2023-06-03 15:05:33.56578	2023-06-03 15:05:33.56578
105	8	ac	Adverse effect of phenothiazine antipsychotics and neuroleptics, initial encounter	pellentesque	Staphylococcal arthritis, shoulder	\N	Spontaneous rupture of flexor tendons	\N	\N	7	2023-06-03 15:05:33.605653	2023-06-03 15:05:33.605653
106	1	dolor	Eclampsia	lacus	Displaced segmental fracture of shaft of ulna, unspecified arm, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	\N	Monteggia's fracture of left ulna, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with malunion	\N	\N	15	2023-06-03 15:05:33.652695	2023-06-03 15:05:33.652695
107	19	erat	Malignant neoplasm of Waldeyer's ring	volutpat	Toxic effect of rattlesnake venom, assault, initial encounter	\N	Contusion of left great toe with damage to nail, sequela	\N	\N	6	2023-06-03 15:05:33.693433	2023-06-03 15:05:33.693433
108	6	vestibulum	Unspecified superficial injury of lower leg	dictumst	Salter-Harris Type II physeal fracture of lower end of radius, left arm, subsequent encounter for fracture with malunion	\N	Nondisplaced apophyseal fracture of right femur, subsequent encounter for closed fracture with nonunion	\N	\N	20	2023-06-03 15:05:33.738966	2023-06-03 15:05:33.738966
109	20	malesuada	Other specified diseases of blood and blood-forming organs	in	Tear of articular cartilage of left knee, current, initial encounter	\N	Laceration of other blood vessels at hip and thigh level, unspecified leg, subsequent encounter	\N	\N	12	2023-06-03 15:05:33.788234	2023-06-03 15:05:33.788234
110	6	lobortis	Burn of third degree of chin	ante	Maternal care for (suspected) fetal abnormality and damage, unspecified, fetus 3	\N	Filamentary keratitis, unspecified eye	\N	\N	1	2023-06-03 15:05:33.829915	2023-06-03 15:05:33.829915
111	5	sit	Rheumatoid nodule, unspecified shoulder	nulla	Legal intervention involving sharp objects	\N	Toxic effect of venom of brown recluse spider, assault, initial encounter	\N	\N	7	2023-06-03 15:05:33.874096	2023-06-03 15:05:33.874096
112	4	elementum	Corrosion of unspecified degree of lower back, initial encounter	nam	Displaced fracture of lateral malleolus of unspecified fibula, initial encounter for open fracture type I or II	\N	Unspecified injury of other blood vessels at lower leg level, unspecified leg, initial encounter	\N	\N	12	2023-06-03 15:05:33.917156	2023-06-03 15:05:33.917156
113	5	in	Omphalitis without hemorrhage	ut	Chronic embolism and thrombosis of superficial veins of unspecified upper extremity	\N	Superficial foreign body, unspecified foot, sequela	\N	\N	18	2023-06-03 15:05:33.961277	2023-06-03 15:05:33.961277
114	13	a	Fracture of unspecified tarsal bone(s) of unspecified foot	in	Underdosing of local anesthetics, subsequent encounter	\N	Toxoplasma chorioretinitis	Toxic effect of carbon tetrachloride, assault, sequela	http://dummyimage.com/229x100.png/cc0000/ffffff	14	2023-06-03 15:05:34.009473	2023-06-03 15:05:34.009473
115	3	elit	Underdosing of other narcotics, initial encounter	sed	Osteonecrosis due to previous trauma, left femur	\N	Displaced oblique fracture of shaft of left tibia, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with nonunion	\N	\N	5	2023-06-03 15:05:34.060724	2023-06-03 15:05:34.060724
116	1	consequat	Toxic effect of other specified inorganic substances, assault, sequela	diam	Follicular lymphoma, unspecified, spleen	\N	Displaced comminuted fracture of left patella, subsequent encounter for open fracture type I or II with nonunion	\N	\N	18	2023-06-03 15:05:34.107238	2023-06-03 15:05:34.107238
117	15	maecenas	Burn of first degree of other site of trunk, initial encounter	etiam	Toxic effect of trichloroethylene, intentional self-harm, sequela	\N	Puncture wound with foreign body of other finger without damage to nail, subsequent encounter	\N	\N	19	2023-06-03 15:05:34.155234	2023-06-03 15:05:34.155234
118	16	lectus	Poisoning by insulin and oral hypoglycemic [antidiabetic] drugs, intentional self-harm, sequela	lobortis	Infection and inflammatory reaction due to internal fixation device of left tibia, initial encounter	\N	Burn of second degree of right ear [any part, except ear drum], sequela	Displacement of biological heart valve graft	http://dummyimage.com/148x100.png/cc0000/ffffff	4	2023-06-03 15:05:34.19926	2023-06-03 15:05:34.19926
119	12	amet	Spinal enthesopathy, site unspecified	nulla	Displaced supracondylar fracture with intracondylar extension of lower end of right femur, subsequent encounter for closed fracture with routine healing	\N	Other streptococcal arthritis, ankle and foot	\N	\N	15	2023-06-03 15:05:34.247101	2023-06-03 15:05:34.247101
120	20	varius	Unspecified injury of femoral vein at hip and thigh level, unspecified leg, sequela	nibh	Maternal care for other specified fetal problems, second trimester, fetus 3	\N	Salter-Harris Type I physeal fracture of right metatarsal, initial encounter for closed fracture	\N	\N	15	2023-06-03 15:05:34.290539	2023-06-03 15:05:34.290539
121	13	donec	Food in trachea causing other injury	dolor	Striking against or struck by other automobile airbag, sequela	\N	Strain of unspecified muscles, fascia and tendons at thigh level	\N	\N	5	2023-06-03 15:05:34.344107	2023-06-03 15:05:34.344107
122	10	turpis	Unspecified fracture of left toe(s), subsequent encounter for fracture with delayed healing	platea	Other fracture of upper end of unspecified radius, subsequent encounter for open fracture type I or II with nonunion	\N	Unspecified injury of femoral vein at hip and thigh level, unspecified leg, sequela	\N	\N	20	2023-06-03 15:05:34.386299	2023-06-03 15:05:34.386299
123	15	lobortis	Unspecified injury of unspecified foot, subsequent encounter	morbi	Person injured while boarding or alighting from snowmobile, subsequent encounter	\N	Insomnia due to other mental disorder	Injury of other nerves at shoulder and upper arm level, unspecified arm, subsequent encounter	http://dummyimage.com/170x100.png/dddddd/000000	3	2023-06-03 15:05:34.433423	2023-06-03 15:05:34.433423
124	9	vestibulum	Other fracture of upper and lower end of unspecified fibula, initial encounter for open fracture type I or II	pede	Chronic pain syndrome	\N	Osteitis deformans of unspecified hand	\N	\N	10	2023-06-03 15:05:34.476687	2023-06-03 15:05:34.476687
125	1	libero	Sprain of metacarpophalangeal joint of unspecified finger, initial encounter	molestie	Corrosion of first degree of right forearm, initial encounter	\N	Partial traumatic amputation of right shoulder and upper arm, level unspecified, subsequent encounter	\N	\N	15	2023-06-03 15:05:34.522524	2023-06-03 15:05:34.522524
126	14	erat	Other specified intracranial injury with loss of consciousness greater than 24 hours without return to pre-existing conscious level with patient surviving, sequela	ante	Displaced fracture of proximal phalanx of unspecified finger, initial encounter for open fracture	\N	Fracture of unspecified part of right clavicle, subsequent encounter for fracture with delayed healing	Personal history of systemic steroid therapy	http://dummyimage.com/154x100.png/ff4444/ffffff	20	2023-06-03 15:05:34.564373	2023-06-03 15:05:34.564373
127	7	et	Contact with hot tap water, undetermined intent, sequela	aenean	Toxic effect of venom of wasps, assault, subsequent encounter	\N	Other spondylosis, occipito-atlanto-axial region	\N	\N	3	2023-06-03 15:05:34.608371	2023-06-03 15:05:34.608371
128	13	eget	Displaced fracture of right tibial tuberosity, subsequent encounter for open fracture type I or II with routine healing	non	Postprocedural seroma of a digestive system organ or structure following other procedure	\N	Toxic effect of carbon monoxide from other source, intentional self-harm, initial encounter	\N	\N	6	2023-06-03 15:05:34.653921	2023-06-03 15:05:34.653921
129	20	imperdiet	Segmental and somatic dysfunction of abdomen and other regions	nulla	Burn of second degree of unspecified hand, unspecified site	\N	Exposure to unspecified man-made visible and ultraviolet light, sequela	Asphyxiation due to smothering under another person's body (in bed), assault, initial encounter	http://dummyimage.com/203x100.png/ff4444/ffffff	19	2023-06-03 15:05:34.698271	2023-06-03 15:05:34.698271
158	2	in	Malignant carcinoid tumors of other sites	proin	Contusion of left thumb without damage to nail, sequela	\N	Other osteoporosis with current pathological fracture, vertebra(e)	\N	\N	5	2023-06-03 15:05:36.442386	2023-06-03 15:05:36.442386
130	6	lorem	Burn due to localized fire on board unspecified watercraft, sequela	non	Nondisplaced fracture of greater trochanter of left femur, initial encounter for open fracture type IIIA, IIIB, or IIIC	\N	Laceration of unspecified blood vessel at shoulder and upper arm level, right arm, sequela	Person on outside of heavy transport vehicle injured in collision with other nonmotor vehicle in nontraffic accident	http://dummyimage.com/195x100.png/5fa2dd/ffffff	6	2023-06-03 15:05:34.73928	2023-06-03 15:05:34.73928
131	11	morbi	Pressure ulcer of left upper back, unspecified stage	dui	Atrophy of orbit	\N	Displaced fracture of anterior column [iliopubic] of unspecified acetabulum, subsequent encounter for fracture with delayed healing	\N	\N	6	2023-06-03 15:05:34.781429	2023-06-03 15:05:34.781429
132	1	lacus	Unspecified injury of superficial palmar arch of unspecified hand, initial encounter	justo	Poisoning by peripheral vasodilators, undetermined, sequela	\N	Other specified industrial and construction area as the place of occurrence of the external cause	\N	\N	2	2023-06-03 15:05:34.825291	2023-06-03 15:05:34.825291
133	1	justo	Stress fracture, unspecified tibia and fibula, subsequent encounter for fracture with delayed healing	dapibus	Other and unspecified degenerative disorders of globe	\N	Laceration of unspecified muscles, fascia and tendons at forearm level, left arm	\N	\N	20	2023-06-03 15:05:34.870295	2023-06-03 15:05:34.870295
134	10	rhoncus	Laceration of other muscles, fascia and tendons at shoulder and upper arm level, left arm, subsequent encounter	condimentum	Injury, poisoning and certain other consequences of external causes complicating childbirth	\N	Frostbite with tissue necrosis of right toe(s)	\N	\N	1	2023-06-03 15:05:34.912506	2023-06-03 15:05:34.912506
135	6	nisl	War operations involving destruction of aircraft due to collision with other aircraft, military personnel, subsequent encounter	condimentum	Drowning and submersion due to sailboat sinking, initial encounter	\N	Exposure to excessive heat of man-made origin, subsequent encounter	\N	\N	10	2023-06-03 15:05:34.956524	2023-06-03 15:05:34.956524
136	17	nam	Cerebral infarction due to unspecified occlusion or stenosis of middle cerebral artery	etiam	Other specified multiple gestation, unspecified number of placenta and unspecified number of amniotic sacs, first trimester	\N	Blister (nonthermal), unspecified thigh	\N	\N	7	2023-06-03 15:05:34.999959	2023-06-03 15:05:34.999959
137	17	vulputate	Toxic effect of venom of other North and South American snake	fringilla	Burn of third degree of scalp [any part], subsequent encounter	\N	Postauricular fistula, right ear	\N	\N	14	2023-06-03 15:05:35.045213	2023-06-03 15:05:35.045213
138	2	leo	Poisoning by unspecified topical agent, accidental (unintentional), sequela	mi	Person on outside of three-wheeled motor vehicle injured in collision with two- or three-wheeled motor vehicle in nontraffic accident, subsequent encounter	\N	Poisoning by propionic acid derivatives, intentional self-harm, initial encounter	\N	\N	10	2023-06-03 15:05:35.09105	2023-06-03 15:05:35.09105
139	11	quis	Voice and resonance disorders	suspendisse	Corrosion of second degree of right ankle, sequela	\N	Nondisplaced transverse fracture of shaft of left radius, initial encounter for open fracture type I or II	\N	\N	15	2023-06-03 15:05:35.134101	2023-06-03 15:05:35.134101
140	17	sit	Hypertrichosis, unspecified	in	Laceration with foreign body of unspecified thumb with damage to nail, sequela	\N	Hypertrophy of breast	\N	\N	11	2023-06-03 15:05:35.180824	2023-06-03 15:05:35.180824
141	14	sapien	Corrosions involving 10-19% of body surface	justo	Other specified spondylopathies, site unspecified	\N	Other malformation of placenta, first trimester	\N	\N	19	2023-06-03 15:05:35.226199	2023-06-03 15:05:35.226199
142	11	lectus	Asphyxiation due to being trapped in bed linens, intentional self-harm, subsequent encounter	cubilia	8 weeks gestation of pregnancy	\N	Presence of other otological and audiological implants	\N	\N	3	2023-06-03 15:05:35.26724	2023-06-03 15:05:35.26724
143	20	arcu	Sprain of other specified parts of shoulder girdle	neque	Other specified bursopathies, unspecified ankle and foot	\N	Cocaine dependence with withdrawal	\N	\N	10	2023-06-03 15:05:35.309368	2023-06-03 15:05:35.309368
144	15	etiam	Sprain of tarsometatarsal ligament of foot	vitae	Penetrating wound with foreign body of right eyeball, subsequent encounter	\N	Nondisplaced fracture of medial phalanx of other finger, sequela	\N	\N	19	2023-06-03 15:05:35.352533	2023-06-03 15:05:35.352533
145	13	tortor	Fracture of unspecified carpal bone, right wrist, subsequent encounter for fracture with routine healing	vulputate	Unspecified injury of descending [left] colon, initial encounter	\N	Lobster-claw hand, bilateral	\N	\N	11	2023-06-03 15:05:35.400238	2023-06-03 15:05:35.400238
146	3	volutpat	Unspecified malignant neoplasm of skin of right ear and external auricular canal	curabitur	Presence of orthopedic joint implants	\N	Skin graft (allograft) (autograft) failure	\N	\N	16	2023-06-03 15:05:35.442702	2023-06-03 15:05:35.442702
147	3	convallis	Rheumatoid arthritis with rheumatoid factor of wrist without organ or systems involvement	at	Citrullinemia	\N	Unspecified injury of right foot, sequela	\N	\N	9	2023-06-03 15:05:35.483873	2023-06-03 15:05:35.483873
148	9	pretium	Anorexia nervosa	integer	Alcohol dependence with withdrawal, uncomplicated	\N	Stable burst fracture of fourth thoracic vertebra, initial encounter for open fracture	\N	\N	10	2023-06-03 15:05:35.526483	2023-06-03 15:05:35.526483
149	20	congue	Algoneurodystrophy, hand	cras	Erysipelas	\N	Other infective otitis externa, unspecified ear	\N	\N	20	2023-06-03 15:05:35.588	2023-06-03 15:05:35.588
150	5	blandit	Injury of optic nerve, right eye, initial encounter	diam	Female cousin, perpetrator of maltreatment and neglect	\N	Burn of first degree of trunk, unspecified site, initial encounter	\N	\N	15	2023-06-03 15:05:35.633956	2023-06-03 15:05:35.633956
151	5	donec	Periodic headache syndromes in child or adult, not intractable	velit	Other kyphosis, thoracolumbar region	\N	Unspecified physeal fracture of lower end of right fibula, subsequent encounter for fracture with malunion	\N	\N	7	2023-06-03 15:05:36.114183	2023-06-03 15:05:36.114183
152	5	leo	Pedestrian with other conveyance injured in collision with car, pick-up truck or van, unspecified whether traffic or nontraffic accident, sequela	ipsum	Unspecified occupant of bus injured in collision with pedal cycle in traffic accident, initial encounter	\N	Zygomatic fracture, right side, sequela	\N	\N	9	2023-06-03 15:05:36.155701	2023-06-03 15:05:36.155701
153	14	sit	Galeazzi's fracture of unspecified radius, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with nonunion	ultrices	Other fracture of fourth metacarpal bone, right hand, sequela	\N	Otitic barotrauma, subsequent encounter	\N	\N	20	2023-06-03 15:05:36.204071	2023-06-03 15:05:36.204071
154	18	mauris	Fall on board fishing boat, initial encounter	nulla	Nondisplaced fracture of base of fourth metacarpal bone, left hand, initial encounter for open fracture	\N	Other nondisplaced fracture of fourth cervical vertebra, initial encounter for closed fracture	\N	\N	16	2023-06-03 15:05:36.253992	2023-06-03 15:05:36.253992
155	18	porttitor	Poisoning by unspecified psychodysleptics [hallucinogens], intentional self-harm	quisque	Cystic meniscus, posterior horn of lateral meniscus	\N	Poisoning by selective serotonin reuptake inhibitors, intentional self-harm	\N	\N	19	2023-06-03 15:05:36.311074	2023-06-03 15:05:36.311074
156	1	a	Laceration of superficial palmar arch of right hand, initial encounter	enim	Displaced fracture of neck of second metacarpal bone, right hand, subsequent encounter for fracture with routine healing	\N	Burn of third degree of left ankle, initial encounter	\N	\N	13	2023-06-03 15:05:36.35124	2023-06-03 15:05:36.35124
157	3	nibh	Electrocution, initial encounter	amet	Other acute skin changes due to ultraviolet radiation	\N	Sprain of unspecified collateral ligament of unspecified knee, subsequent encounter	\N	\N	7	2023-06-03 15:05:36.39642	2023-06-03 15:05:36.39642
159	13	donec	Other fracture of upper end of right tibia, subsequent encounter for closed fracture with delayed healing	tortor	Injury of cutaneous sensory nerve at lower leg level, unspecified leg, subsequent encounter	\N	Smith's fracture of unspecified radius, initial encounter for open fracture type IIIA, IIIB, or IIIC	\N	\N	17	2023-06-03 15:05:36.487259	2023-06-03 15:05:36.487259
160	8	nulla	Atherosclerosis of nonbiological bypass graft(s) of the left leg with ulceration of ankle	maecenas	Discoid lupus erythematosus of left eye, unspecified eyelid	\N	Bucket-handle tear of medial meniscus, current injury, left knee, initial encounter	\N	\N	16	2023-06-03 15:05:36.530217	2023-06-03 15:05:36.530217
161	19	luctus	Corrosion of first degree of lip(s), subsequent encounter	a	Unspecified Zone III fracture of sacrum, subsequent encounter for fracture with routine healing	\N	Other chronic osteomyelitis, radius and ulna	\N	\N	5	2023-06-03 15:05:36.571993	2023-06-03 15:05:36.571993
162	7	venenatis	Other injury of muscle, fascia and tendon of pelvis, subsequent encounter	justo	Corrosion of unspecified degree of left shoulder, sequela	\N	Nontraumatic intracerebral hemorrhage in hemisphere, cortical	\N	\N	11	2023-06-03 15:05:36.614707	2023-06-03 15:05:36.614707
163	12	sed	Contact with other specified agricultural machinery, initial encounter	nam	Cholesteatoma of attic, bilateral	\N	Complete oblique atypical femoral fracture, unspecified leg, subsequent encounter for fracture with routine healing	\N	\N	9	2023-06-03 15:05:36.656973	2023-06-03 15:05:36.656973
164	14	non	Displaced unspecified fracture of right lesser toe(s), subsequent encounter for fracture with nonunion	mollis	Vestibular neuronitis, right ear	\N	Nondisplaced fracture of base of neck of unspecified femur, subsequent encounter for open fracture type I or II with nonunion	\N	\N	9	2023-06-03 15:05:36.7022	2023-06-03 15:05:36.7022
165	3	sapien	Congenital compression facies	quam	Strain of unspecified Achilles tendon	\N	Poisoning by selective serotonin and norepinephrine reuptake inhibitors, undetermined, sequela	\N	\N	1	2023-06-03 15:05:36.752106	2023-06-03 15:05:36.752106
166	14	phasellus	Other congenital malformations of esophagus	ante	Rapidly progressive nephritic syndrome with unspecified morphologic changes	\N	Pathological fracture in neoplastic disease, unspecified femur, sequela	\N	\N	8	2023-06-03 15:05:36.794754	2023-06-03 15:05:36.794754
167	19	at	Unspecified injury of pleura, subsequent encounter	elementum	Displaced fracture of distal phalanx of other finger, initial encounter for open fracture	\N	Poisoning by antihyperlipidemic and antiarteriosclerotic drugs, accidental (unintentional)	\N	\N	9	2023-06-03 15:05:36.88586	2023-06-03 15:05:36.88586
168	17	urna	Displaced spiral fracture of shaft of radius, right arm, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	posuere	Unspecified fracture of upper end of right radius, initial encounter for closed fracture	\N	Unspecified transfusion reaction, sequela	\N	\N	4	2023-06-03 15:05:36.947028	2023-06-03 15:05:36.947028
169	10	justo	Other displaced fracture of upper end of right humerus	morbi	Maternal care for other specified fetal problems, second trimester, fetus 3	\N	Strain of unspecified muscles, fascia and tendons at thigh level, left thigh	\N	\N	10	2023-06-03 15:05:36.995932	2023-06-03 15:05:36.995932
170	1	elementum	Contact with transmission devices, not elsewhere classified	eu	Unspecified fracture of shaft of unspecified femur, subsequent encounter for closed fracture with nonunion	\N	Lead-induced chronic gout, unspecified wrist, without tophus (tophi)	\N	\N	9	2023-06-03 15:05:37.042543	2023-06-03 15:05:37.042543
171	12	turpis	Ciguatera fish poisoning, undetermined	donec	Minor laceration of right internal jugular vein, initial encounter	\N	Family history of malignant neoplasm of bladder	Salter-Harris Type IV physeal fracture of lower end of ulna, left arm, sequela	http://dummyimage.com/220x100.png/cc0000/ffffff	16	2023-06-03 15:05:37.085043	2023-06-03 15:05:37.085043
172	1	vestibulum	Subluxation of metacarpophalangeal joint of right little finger	volutpat	Sprain of anterior cruciate ligament of knee	\N	Unspecified displaced fracture of surgical neck of right humerus, subsequent encounter for fracture with routine healing	\N	\N	5	2023-06-03 15:05:37.138193	2023-06-03 15:05:37.138193
173	4	morbi	Coronary artery dissection	nisl	Poisoning by macrolides, assault	\N	Other fracture of lower end of left femur, initial encounter for closed fracture	\N	\N	3	2023-06-03 15:05:37.183892	2023-06-03 15:05:37.183892
174	6	suscipit	Anaphylactic reaction due to fruits and vegetables, sequela	dapibus	Other injury of other part of colon, sequela	\N	Amusement park as the place of occurrence of the external cause	\N	\N	9	2023-06-03 15:05:37.244887	2023-06-03 15:05:37.244887
175	17	rhoncus	Failure of sterile precautions during kidney dialysis and other perfusion	turpis	Unspecified injury of unspecified muscles, fascia and tendons at forearm level, unspecified arm, sequela	\N	Nondisplaced fracture of shaft of fourth metacarpal bone, left hand, subsequent encounter for fracture with delayed healing	\N	\N	3	2023-06-03 15:05:37.330955	2023-06-03 15:05:37.330955
176	11	posuere	Minor laceration of kidney	lectus	Acquired atrophy of ovary and fallopian tube	\N	Alcohol use, unspecified with alcohol-induced psychotic disorder, unspecified	\N	\N	3	2023-06-03 15:05:37.374959	2023-06-03 15:05:37.374959
177	1	donec	Malignant neoplasm of nasopharynx	dolor	Other physeal fracture of lower end of radius, left arm, subsequent encounter for fracture with malunion	\N	Pathological fracture in neoplastic disease, pelvis, subsequent encounter for fracture with nonunion	\N	\N	14	2023-06-03 15:05:37.420142	2023-06-03 15:05:37.420142
178	17	et	Strain of intrinsic muscle, fascia and tendon of left index finger at wrist and hand level	cras	Burn of second degree of left axilla, initial encounter	\N	Unspecified effects of vibration, subsequent encounter	\N	\N	18	2023-06-03 15:05:37.46614	2023-06-03 15:05:37.46614
179	11	habitasse	Poisoning by thrombolytic drug, accidental (unintentional)	faucibus	Minor laceration of liver, sequela	\N	Fatigue fracture of vertebra, thoracic region, initial encounter for fracture	\N	\N	14	2023-06-03 15:05:37.507748	2023-06-03 15:05:37.507748
180	2	primis	Dislocation of metacarpophalangeal joint of left index finger, sequela	augue	Puncture wound without foreign body of right ring finger without damage to nail, initial encounter	\N	Lichen nitidus	\N	\N	3	2023-06-03 15:05:37.551354	2023-06-03 15:05:37.551354
181	7	habitasse	Poisoning by barbiturates, accidental (unintentional)	ridiculus	Adverse effect of oral contraceptives	\N	Nondisplaced fracture of lower epiphysis (separation) of left femur, subsequent encounter for closed fracture with routine healing	\N	\N	2	2023-06-03 15:05:37.607091	2023-06-03 15:05:37.607091
182	18	nullam	Vomiting	suscipit	Person on outside of pick-up truck or van injured in collision with pedestrian or animal in nontraffic accident	\N	Displacement of unspecified cardiac and vascular devices and implants, subsequent encounter	\N	\N	5	2023-06-03 15:05:37.659029	2023-06-03 15:05:37.659029
183	15	condimentum	Poisoning by, adverse effect of and underdosing of monoamine-oxidase-inhibitor antidepressants	augue	Strain of muscle and tendon of long extensor muscle of toe at ankle and foot level, unspecified foot	\N	Acute ethmoidal sinusitis	\N	\N	2	2023-06-03 15:05:37.70473	2023-06-03 15:05:37.70473
184	19	sapien	Unspecified superficial injury of abdomen, lower back, pelvis and external genitals	justo	Displaced comminuted supracondylar fracture without intercondylar fracture of right humerus, initial encounter for open fracture	\N	Unspecified injury of muscle, fascia and tendon of abdomen, lower back and pelvis	\N	\N	15	2023-06-03 15:05:37.747368	2023-06-03 15:05:37.747368
185	16	suscipit	Laceration of other blood vessels at lower leg level, left leg, initial encounter	in	Assault by unspecified sharp object, sequela	\N	Colic	\N	\N	18	2023-06-03 15:05:37.809303	2023-06-03 15:05:37.809303
186	20	donec	Unspecified injury of intercostal blood vessels, right side, subsequent encounter	eu	Toxic effect of other ingested (parts of) plant(s), accidental (unintentional), sequela	\N	Puncture wound without foreign body of right shoulder, initial encounter	\N	\N	3	2023-06-03 15:05:37.86333	2023-06-03 15:05:37.86333
187	11	ut	Nondisplaced fracture of shaft of fifth metacarpal bone, left hand	lectus	Other secondary chronic gout, right shoulder, without tophus (tophi)	\N	Arthritis due to other bacteria, unspecified knee	\N	\N	20	2023-06-03 15:05:37.922588	2023-06-03 15:05:37.922588
188	13	semper	Poisoning by hemostatic drug, intentional self-harm, initial encounter	eget	Salter-Harris Type IV physeal fracture of upper end of unspecified tibia, subsequent encounter for fracture with malunion	\N	Displaced pilon fracture of unspecified tibia, subsequent encounter for open fracture type I or II with malunion	\N	\N	7	2023-06-03 15:05:37.998993	2023-06-03 15:05:37.998993
189	8	et	Fall from in-line roller-skates, initial encounter	ligula	Activities involving animal care	\N	Mechanical loosening of internal left hip prosthetic joint, initial encounter	\N	\N	19	2023-06-03 15:05:38.047127	2023-06-03 15:05:38.047127
190	12	donec	Salter-Harris Type IV physeal fracture of right calcaneus	iaculis	Hordeolum internum right lower eyelid	\N	Other fracture of upper end of unspecified ulna, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with delayed healing	\N	\N	18	2023-06-03 15:05:38.095133	2023-06-03 15:05:38.095133
191	14	iaculis	Crushing injury of unspecified forearm, sequela	nascetur	Other dislocation of right wrist and hand, subsequent encounter	\N	Maternal care for excessive fetal growth, unspecified trimester, fetus 1	\N	\N	12	2023-06-03 15:05:38.151724	2023-06-03 15:05:38.151724
192	8	duis	Other chondrocalcinosis, left hand	cum	Drug-induced chronic gout, right wrist, without tophus (tophi)	\N	Laceration of other specified blood vessels at shoulder and upper arm level, left arm, initial encounter	\N	\N	18	2023-06-03 15:05:38.209735	2023-06-03 15:05:38.209735
193	6	molestie	Carcinoma in situ of skin of left ear and external auricular canal	sed	Maternal care for viable fetus in abdominal pregnancy, second trimester, fetus 3	\N	Unspecified trochanteric fracture of left femur, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	\N	\N	3	2023-06-03 15:05:38.263004	2023-06-03 15:05:38.263004
194	20	porta	Other mechanical complication of other urinary devices and implants, initial encounter	viverra	Mechanical loosening of unspecified internal prosthetic joint, subsequent encounter	\N	Malignant neoplasm of left spermatic cord	\N	\N	13	2023-06-03 15:05:38.30571	2023-06-03 15:05:38.30571
195	1	lectus	Other foreign object in trachea causing other injury, sequela	faucibus	Split foot, right lower limb	\N	Miscellaneous cardiovascular devices associated with adverse incidents, not elsewhere classified	\N	\N	18	2023-06-03 15:05:38.365052	2023-06-03 15:05:38.365052
196	15	faucibus	Person on outside of car injured in collision with other type car in nontraffic accident	feugiat	Unspecified physeal fracture of lower end of right fibula, initial encounter for closed fracture	\N	Crushing injury of right thigh, subsequent encounter	\N	\N	16	2023-06-03 15:05:38.43103	2023-06-03 15:05:38.43103
197	4	pharetra	Nondisplaced fracture of anterior column [iliopubic] of right acetabulum, subsequent encounter for fracture with delayed healing	nibh	Displaced osteochondral fracture of right patella, subsequent encounter for open fracture type I or II with routine healing	\N	Spontaneous rupture of flexor tendons, left shoulder	Contact with hot stove (kitchen), initial encounter	http://dummyimage.com/232x100.png/dddddd/000000	4	2023-06-03 15:05:38.478702	2023-06-03 15:05:38.478702
198	12	lectus	Unspecified fracture of shaft of unspecified ulna, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with delayed healing	tristique	Posterior dislocation of left radial head, initial encounter	\N	Other myositis, left lower leg	\N	\N	6	2023-06-03 15:05:38.52687	2023-06-03 15:05:38.52687
199	8	amet	Other dorsalgia	luctus	Other nondisplaced fracture of lower end of right humerus, initial encounter for closed fracture	\N	Nondisplaced spiral fracture of shaft of radius, unspecified arm, subsequent encounter for closed fracture with routine healing	\N	\N	20	2023-06-03 15:05:38.582963	2023-06-03 15:05:38.582963
200	20	duis	Neuromuscular scoliosis, lumbar region	justo	Displaced fracture of navicular [scaphoid] of unspecified foot, initial encounter for open fracture	\N	Displaced spiral fracture of shaft of right tibia, initial encounter for open fracture type IIIA, IIIB, or IIIC	\N	\N	19	2023-06-03 15:05:38.64447	2023-06-03 15:05:38.64447
\.


--
-- Data for Name: flashcard_set; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.flashcard_set (fc_set_id, fc_type_id, name, description, words_count, system_belong, access, views, created_by, created_at, updated_at) FROM stdin;
11	2	Phalacrocorax varius	Therapeutic Exercise Treatment of Integumentary System - Lower Back / Lower Extremity using Other Equipment	9	t	public	437	9	2023-06-03 15:05:27.038968	2023-06-03 15:05:37.922588
13	1	Phalaropus fulicarius	Extraction of Left Shoulder Bursa and Ligament, Open Approach	11	f	private	198	12	2023-06-03 15:05:27.131632	2023-06-03 15:05:37.998993
10	2	Raphicerus campestris	Division of Left Upper Leg Subcutaneous Tissue and Fascia, Percutaneous Approach	11	f	private	419	4	2023-06-03 15:05:26.997593	2023-06-03 15:05:36.995932
14	3	Heloderma horridum	Lower Arteries, Drainage	11	f	public	441	7	2023-06-03 15:05:27.174025	2023-06-03 15:05:38.151724
9	1	unavailable	Bypass Left Lesser Saphenous Vein to Lower Vein with Autologous Arterial Tissue, Open Approach	5	f	public	969	5	2023-06-03 15:05:26.954959	2023-06-03 15:05:35.526483
17	2	Crotaphytus collaris	Revision of Synthetic Substitute in Left Breast, Via Natural or Artificial Opening Endoscopic	9	f	private	177	12	2023-06-03 15:05:27.344997	2023-06-03 15:05:37.46614
2	2	Naja haje	Release Left Inguinal Lymphatic, Open Approach	6	t	private	739	7	2023-06-03 15:05:26.600805	2023-06-03 15:05:37.551354
7	2	Crocuta crocuta	Dilation of Right Radial Artery with Two Intraluminal Devices, Open Approach	7	t	private	995	17	2023-06-03 15:05:26.862969	2023-06-03 15:05:37.607091
5	2	Alligator mississippiensis	Insertion of Infusion Device into Lumbar Vertebral Joint, Open Approach	9	t	private	254	8	2023-06-03 15:05:26.750953	2023-06-03 15:05:36.155701
18	3	Lamprotornis nitens	Drainage of Right Thumb Phalanx, Percutaneous Approach	6	f	public	960	7	2023-06-03 15:05:27.39361	2023-06-03 15:05:37.659029
19	3	Psophia viridis	Bypass Left Ureter to Cutaneous with Autologous Tissue Substitute, Percutaneous Endoscopic Approach	14	f	private	221	15	2023-06-03 15:05:27.436604	2023-06-03 15:05:37.747368
15	1	Columba palumbus	Replacement of Left Hand Artery with Nonautologous Tissue Substitute, Percutaneous Endoscopic Approach	14	f	public	360	2	2023-06-03 15:05:27.218281	2023-06-03 15:05:38.43103
4	2	Phalaropus lobatus	Dilation of Right Ureter with Intraluminal Device, Percutaneous Approach	7	f	public	967	4	2023-06-03 15:05:26.702994	2023-06-03 15:05:38.478702
12	3	Bubalus arnee	Plain Radiography of Vasa Vasorum using Low Osmolar Contrast	11	t	private	268	8	2023-06-03 15:05:27.088286	2023-06-03 15:05:38.52687
16	2	Felis wiedi or Leopardus weidi	Extirpation of Matter from Right Hip Joint, Percutaneous Endoscopic Approach	6	t	private	309	11	2023-06-03 15:05:27.262704	2023-06-03 15:05:37.809303
8	2	Choloepus hoffmani	Urinary System, Bypass	14	f	private	446	17	2023-06-03 15:05:26.910534	2023-06-03 15:05:38.582963
20	3	Tayassu tajacu	Supplement Right Thyroid Artery with Nonautologous Tissue Substitute, Percutaneous Approach	13	t	private	876	3	2023-06-03 15:05:27.480802	2023-06-03 15:05:38.64447
3	1	Petaurus breviceps	Fragmentation in Ampulla of Vater, Percutaneous Approach	8	f	public	266	12	2023-06-03 15:05:26.646954	2023-06-03 15:16:05.245813
1	1	Microcebus murinus	Dilation of Face Artery, Bifurcation, with Drug-eluting Intraluminal Device, Open Approach	16	f	private	848	11	2023-06-03 15:05:26.54966	2023-06-03 15:16:08.897177
6	1	Paraxerus cepapi	Replacement of Lower Artery with Nonautologous Tissue Substitute, Open Approach	13	t	public	26	13	2023-06-03 15:05:26.809101	2023-06-03 15:20:32.035909
\.


--
-- Data for Name: flashcard_share_permit; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.flashcard_share_permit (user_id, fc_set_id, created_at) FROM stdin;
\.


--
-- Data for Name: flashcard_type; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.flashcard_type (fc_type_id, type, description, sets_count, created_at, updated_at) FROM stdin;
1	IELTS	Flashcard liên quan tới IELTS. Học chúng sẽ giúp bạn làm bài thi IELTS mượt như cá gặp nước.	6	2023-06-03 15:05:26.206147	2023-06-03 15:05:27.218281
2	TOEIC	Cung cấp cho bạn hàng tỉ flashcard. Bạn sẽ không còn sợ khi làm bài thi TOEIC nữa.	9	2023-06-03 15:05:26.253917	2023-06-03 15:05:27.344997
3	Từ vựng hàng ngày	10 phút mỗi ngày với những từ vựng này, sau 1 tháng bạn bỗng trở thành người bản xứ.	5	2023-06-03 15:05:26.301344	2023-06-03 15:05:27.480802
\.


--
-- Data for Name: hashtag; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.hashtag (hashtag_id, name, created_at, updated_at) FROM stdin;
1	[Part 1] Tranh tả người	2023-06-03 23:24:23.626088	2023-06-03 23:24:23.626088
2	[Part 1] Tranh tả vật	2023-06-03 23:24:23.681014	2023-06-03 23:24:23.681014
3	[Part 2] Câu hỏi 5W1H - what/ which	2023-06-03 23:24:23.723391	2023-06-03 23:24:23.723391
4	[Part 2] Câu hỏi 5W1H - who	2023-06-03 23:24:23.766674	2023-06-03 23:24:23.766674
5	[Part 2] Câu hỏi 5W1H - where	2023-06-03 23:24:23.80879	2023-06-03 23:24:23.80879
6	[Part 2] Câu hỏi 5W1H - when	2023-06-03 23:24:23.850868	2023-06-03 23:24:23.850868
7	[Part 2] Câu hỏi 5W1H - how	2023-06-03 23:24:23.893383	2023-06-03 23:24:23.893383
8	[Part 2] Câu hỏi 5W1H - why	2023-06-03 23:24:23.937514	2023-06-03 23:24:23.937514
9	[Part 2] Câu hỏi Yes/ No	2023-06-03 23:24:23.981523	2023-06-03 23:24:23.981523
10	[Part 2] Câu hỏi gián tiếp	2023-06-03 23:24:24.027109	2023-06-03 23:24:24.027109
11	[Part 2] Câu hỏi đuôi	2023-06-03 23:24:24.069606	2023-06-03 23:24:24.069606
12	[Part 2] Câu hỏi lựa chọn	2023-06-03 23:24:24.112093	2023-06-03 23:24:24.112093
13	[Part 2] Câu hỏi đề nghị, yêu cầu	2023-06-03 23:24:24.155095	2023-06-03 23:24:24.155095
14	[Part 2] Câu trần thuật	2023-06-03 23:24:24.25781	2023-06-03 23:24:24.25781
15	[Part 3] Câu hỏi về thông tin, danh tính người nói	2023-06-03 23:24:24.300047	2023-06-03 23:24:24.300047
16	[Part 3] Câu hỏi về chi tiết cuộc đối thoại	2023-06-03 23:24:24.342273	2023-06-03 23:24:24.342273
17	[Part 3] Câu hỏi về hành động trong tương lai	2023-06-03 23:24:24.384401	2023-06-03 23:24:24.384401
18	[Part 3] Câu hỏi kết hợp biểu đồ, bản đồ	2023-06-03 23:24:24.426621	2023-06-03 23:24:24.426621
19	[Part 3] Câu hỏi về ngụ ý câu nói	2023-06-03 23:24:24.469444	2023-06-03 23:24:24.469444
20	[Part 3] Nội dung: Company - General Office Work	2023-06-03 23:24:24.529518	2023-06-03 23:24:24.529518
21	[Part 3] Nội dung: Company - Greetings	2023-06-03 23:24:24.603185	2023-06-03 23:24:24.603185
22	[Part 3] Nội dung: Company - Events	2023-06-03 23:24:24.645351	2023-06-03 23:24:24.645351
23	[Part 3] Nội dung: Company - Facilities	2023-06-03 23:24:24.688128	2023-06-03 23:24:24.688128
24	[Part 3] Nội dung: Shopping	2023-06-03 23:24:24.730862	2023-06-03 23:24:24.730862
25	[Part 3] Nội dung: Order, shipping	2023-06-03 23:24:24.774455	2023-06-03 23:24:24.774455
26	[Part 3] Nội dung: Housing	2023-06-03 23:24:24.816664	2023-06-03 23:24:24.816664
27	[Part 4] Câu hỏi về chủ đề, mục đích	2023-06-03 23:24:24.859243	2023-06-03 23:24:24.859243
28	[Part 4] Câu hỏi về thông tin, danh tính người nói	2023-06-03 23:24:24.903377	2023-06-03 23:24:24.903377
29	[Part 4] Câu hỏi về chi tiết cuộc đối thoại	2023-06-03 23:24:24.985396	2023-06-03 23:24:24.985396
30	[Part 4] Câu hỏi về hành động trong tương lai	2023-06-03 23:24:25.03938	2023-06-03 23:24:25.03938
31	[Part 4] Câu hỏi kết hợp biểu đồ, bản đồ	2023-06-03 23:24:25.08721	2023-06-03 23:24:25.08721
32	[Part 4] Câu hỏi về ngụ ý câu nói	2023-06-03 23:24:25.133182	2023-06-03 23:24:25.133182
33	[Part 4] Hình thức: Telephone message	2023-06-03 23:24:25.175623	2023-06-03 23:24:25.175623
34	[Part 4] Hình thức: Advertisement	2023-06-03 23:24:25.220532	2023-06-03 23:24:25.220532
35	[Part 4] Hình thức: Announcement	2023-06-03 23:24:25.263022	2023-06-03 23:24:25.263022
36	[Part 4] Hình thức: Radio broadcast	2023-06-03 23:24:25.305616	2023-06-03 23:24:25.305616
37	[Part 4] Hình thức: Speech/ talk	2023-06-03 23:24:25.349221	2023-06-03 23:24:25.349221
38	[Part 5] Câu hỏi từ loại	2023-06-03 23:24:25.391634	2023-06-03 23:24:25.391634
39	[Part 5] Câu hỏi ngữ pháp	2023-06-03 23:24:25.438953	2023-06-03 23:24:25.438953
40	[Part 5] Câu hỏi từ vựng 	2023-06-03 23:24:25.500334	2023-06-03 23:24:25.500334
41	[Part 5] Câu hỏi từ loại	2023-06-03 23:24:25.544643	2023-06-03 23:24:25.544643
42	[Part 6] Câu hỏi ngữ pháp	2023-06-03 23:24:25.587364	2023-06-03 23:24:25.587364
43	[Part 6] Câu hỏi từ vựng	2023-06-03 23:24:25.629616	2023-06-03 23:24:25.629616
44	[Part 6] Câu hỏi điền câu	2023-06-03 23:24:25.672041	2023-06-03 23:24:25.672041
45	[Part 6] Hình thức: Thư điện tử/ thư tay (Email/ Letter)	2023-06-03 23:24:25.715151	2023-06-03 23:24:25.715151
46	[Part 6] Hình thức: Thông báo/ văn bản hướng dẫn (Notice/ Announcement Information)	2023-06-03 23:24:25.757412	2023-06-03 23:24:25.757412
47	[Part 7] Câu hỏi tìm thông tin: câu hỏi 5W1H	2023-06-03 23:24:25.800032	2023-06-03 23:24:25.800032
48	[Part 7] Câu hỏi tìm thông tin: câu hỏi NOT/ TRUE	2023-06-03 23:24:25.842996	2023-06-03 23:24:25.842996
49	[Part 7] Câu hỏi suy luận: câu hỏi về chủ đề, mục đích	2023-06-03 23:24:25.893016	2023-06-03 23:24:25.893016
50	[Part 7] Câu hỏi suy luận: câu hỏi 5W1H 	2023-06-03 23:24:25.951279	2023-06-03 23:24:25.951279
51	[Part 7] Câu hỏi suy luận: câu hỏi NOT/ TRUE	2023-06-03 23:24:25.993529	2023-06-03 23:24:25.993529
52	[Part 7] Câu hỏi điền câu	2023-06-03 23:24:26.04288	2023-06-03 23:24:26.04288
53	[Part 7] Cấu trúc: một đoạn	2023-06-03 23:24:26.099208	2023-06-03 23:24:26.099208
54	[Part 7] Cấu trúc: nhiều đoạn	2023-06-03 23:24:26.14695	2023-06-03 23:24:26.14695
55	[Part 7] Hình thức: Thư điện tử/ thư tay (Email/ Letter)	2023-06-03 23:24:26.193086	2023-06-03 23:24:26.193086
56	[Part 7] Hình thức: Bài báo (Article/ Review)	2023-06-03 23:24:26.242299	2023-06-03 23:24:26.242299
57	[Part 7] Hình thức: Quảng cáo (Advertisement)	2023-06-03 23:24:26.286347	2023-06-03 23:24:26.286347
58	[Part 7] Hình thức: Thông báo/ văn bản hướng dẫn (Notice/ Announcement information)	2023-06-03 23:24:26.329052	2023-06-03 23:24:26.329052
59	[Part 7] Hình thức: Chuỗi tin nhắn (Text message)	2023-06-03 23:24:26.393481	2023-06-03 23:24:26.393481
60	[Part 7] Câu hỏi tìm từ đồng nghĩa	2023-06-03 23:24:26.480342	2023-06-03 23:24:26.480342
61	[Part 7] Câu hỏi suy luận: câu hỏi về ngụ ý câu nói	2023-06-03 23:24:26.52263	2023-06-03 23:24:26.52263
\.


--
-- Data for Name: join_course; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.join_course (student_id, course_id, created_at) FROM stdin;
2	1	2023-06-03 15:04:53.625463
2	2	2023-06-03 15:04:53.671472
2	3	2023-06-03 15:04:53.71731
2	4	2023-06-03 15:04:53.757568
2	5	2023-06-03 15:04:53.799982
2	6	2023-06-03 15:04:53.860366
2	7	2023-06-03 15:04:53.919839
2	8	2023-06-03 15:04:53.963312
2	9	2023-06-03 15:04:54.004442
3	10	2023-06-03 15:04:54.051391
3	1	2023-06-03 15:04:54.101641
3	3	2023-06-03 15:04:54.145849
3	5	2023-06-03 15:04:54.187022
3	7	2023-06-03 15:04:54.230501
3	9	2023-06-03 15:04:54.275512
\.


--
-- Data for Name: join_lesson; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.join_lesson (student_id, lesson_id, created_at) FROM stdin;
2	1	2023-06-03 15:04:54.318765
2	21	2023-06-03 15:04:54.379163
2	31	2023-06-03 15:04:54.634321
2	41	2023-06-03 15:04:54.734378
2	51	2023-06-03 15:04:54.77847
2	61	2023-06-03 15:04:54.819281
2	111	2023-06-03 15:04:54.879232
2	171	2023-06-03 15:04:54.924589
2	181	2023-06-03 15:04:54.966781
2	191	2023-06-03 15:04:55.015625
2	261	2023-06-03 15:04:55.058619
2	271	2023-06-03 15:04:55.106362
2	281	2023-06-03 15:04:55.148784
2	291	2023-06-03 15:04:55.191201
3	31	2023-06-03 15:04:55.246953
3	41	2023-06-03 15:04:55.291152
3	51	2023-06-03 15:04:55.34106
3	61	2023-06-03 15:04:55.391204
3	111	2023-06-03 15:04:55.440092
3	171	2023-06-03 15:04:55.507385
3	181	2023-06-03 15:04:55.553439
3	191	2023-06-03 15:04:55.599906
3	261	2023-06-03 15:04:55.644739
3	271	2023-06-03 15:04:55.685904
\.


--
-- Data for Name: learnt_list; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.learnt_list (fc_id, user_id, created_at) FROM stdin;
35	9	2023-06-03 15:05:38.78298
83	16	2023-06-03 15:05:38.843359
55	20	2023-06-03 15:05:38.930622
83	15	2023-06-03 15:05:38.982992
129	15	2023-06-03 15:05:39.0287
56	11	2023-06-03 15:05:39.074966
88	2	2023-06-03 15:05:39.189181
45	12	2023-06-03 15:05:39.233883
98	13	2023-06-03 15:05:39.286974
45	14	2023-06-03 15:05:39.349522
166	3	2023-06-03 15:05:39.39547
155	2	2023-06-03 15:05:39.452647
188	6	2023-06-03 15:05:39.515249
196	6	2023-06-03 15:05:39.559171
147	17	2023-06-03 15:05:39.604503
35	19	2023-06-03 15:05:39.650111
49	5	2023-06-03 15:05:39.794555
152	10	2023-06-03 15:05:39.842403
19	2	2023-06-03 15:05:39.887185
52	18	2023-06-03 15:05:39.931927
49	14	2023-06-03 15:05:39.974824
170	19	2023-06-03 15:05:40.020126
189	3	2023-06-03 15:05:40.062281
163	10	2023-06-03 15:05:40.119951
116	17	2023-06-03 15:05:40.232285
99	13	2023-06-03 15:05:40.331287
81	2	2023-06-03 15:05:40.379093
108	18	2023-06-03 15:05:40.42619
174	16	2023-06-03 15:05:40.478724
13	4	2023-06-03 15:05:40.540115
25	18	2023-06-03 15:05:40.580857
154	16	2023-06-03 15:05:40.737854
66	1	2023-06-03 15:05:40.811831
194	13	2023-06-03 15:05:40.88376
158	19	2023-06-03 15:05:40.944459
85	5	2023-06-03 15:05:41.00337
147	20	2023-06-03 15:05:41.059011
174	12	2023-06-03 15:05:41.134338
37	3	2023-06-03 15:05:41.238964
10	15	2023-06-03 15:05:41.285292
85	4	2023-06-03 15:05:41.331669
29	2	2023-06-03 15:05:41.377507
169	20	2023-06-03 15:05:41.427641
19	3	2023-06-03 15:05:41.476382
191	19	2023-06-03 15:05:41.519264
163	5	2023-06-03 15:05:41.565586
123	3	2023-06-03 15:05:41.611556
81	20	2023-06-03 15:05:41.663903
135	17	2023-06-03 15:05:41.778398
157	19	2023-06-03 15:05:42.154968
50	12	2023-06-03 15:05:42.202607
1	10	2023-06-03 15:05:42.337151
131	17	2023-06-03 15:05:42.43431
125	8	2023-06-03 15:05:42.480819
23	9	2023-06-03 15:05:42.534325
193	3	2023-06-03 15:05:42.578829
182	9	2023-06-03 15:05:42.634384
120	13	2023-06-03 15:05:42.742649
57	3	2023-06-03 15:05:42.834324
63	12	2023-06-03 15:05:42.934322
57	1	2023-06-03 15:05:43.034324
152	12	2023-06-03 15:05:43.086424
111	6	2023-06-03 15:05:43.129065
113	6	2023-06-03 15:05:43.169614
143	9	2023-06-03 15:05:43.210229
165	10	2023-06-03 15:05:43.251469
77	20	2023-06-03 15:05:43.297047
145	9	2023-06-03 15:05:43.340821
44	2	2023-06-03 15:05:43.380495
11	18	2023-06-03 15:05:43.43285
110	3	2023-06-03 15:05:43.475167
119	20	2023-06-03 15:05:43.518303
139	1	2023-06-03 15:05:43.562542
5	20	2023-06-03 15:05:43.610345
19	20	2023-06-03 15:05:43.674356
87	9	2023-06-03 15:05:43.72005
38	2	2023-06-03 15:05:43.763913
4	10	2023-06-03 15:05:43.810582
65	2	2023-06-03 15:05:43.856877
146	13	2023-06-03 15:05:43.896988
192	3	2023-06-03 15:05:43.938158
192	11	2023-06-03 15:05:43.978539
173	15	2023-06-03 15:05:44.028673
155	19	2023-06-03 15:05:44.071939
62	12	2023-06-03 15:05:44.112859
171	4	2023-06-03 15:05:44.170949
139	9	2023-06-03 15:05:44.218944
153	14	2023-06-03 15:05:44.261688
193	11	2023-06-03 15:05:44.32209
130	9	2023-06-03 15:05:44.366984
61	2	2023-06-03 15:05:44.414779
184	11	2023-06-03 15:05:44.463049
10	18	2023-06-03 15:05:44.518319
112	16	2023-06-03 15:05:44.562952
56	12	2023-06-03 15:05:44.606936
155	18	2023-06-03 15:05:44.649411
46	11	2023-06-03 15:05:44.695164
186	9	2023-06-03 15:05:44.738955
17	15	2023-06-03 15:05:44.785365
141	14	2023-06-03 15:05:44.827979
\.


--
-- Data for Name: lesson; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.lesson (lesson_id, unit_id, numeric_order, name, type, video_url, video_time, flashcard_set_id, text, description, created_at, updated_at) FROM stdin;
1	1	1	Flexidy	3	http://dummyimage.com/146x100.png/ff4444/ffffff	0	0	Sprain of tarsometatarsal ligament of left foot, initial encounter	Parent-adopted child conflict	2023-06-03 15:04:34.188163	2023-06-03 15:04:34.188163
2	2	1	Job	3	http://dummyimage.com/131x100.png/cc0000/ffffff	0	0	Driver of snowmobile injured in traffic accident	Other specified injury of other blood vessels at wrist and hand level of unspecified arm, sequela	2023-06-03 15:04:34.236131	2023-06-03 15:04:34.236131
3	3	1	Stronghold	3	http://dummyimage.com/120x100.png/cc0000/ffffff	0	0	Acute perichondritis of external ear	Poisoning by other viral vaccines, undetermined, initial encounter	2023-06-03 15:04:34.281404	2023-06-03 15:04:34.281404
4	4	1	Holdlamis	3	http://dummyimage.com/150x100.png/ff4444/ffffff	0	0	Displaced fracture of trapezoid [smaller multangular], unspecified wrist, initial encounter for closed fracture	Unspecified fracture of third thoracic vertebra, subsequent encounter for fracture with routine healing	2023-06-03 15:04:34.326496	2023-06-03 15:04:34.326496
5	5	1	Andalax	2	http://dummyimage.com/179x100.png/ff4444/ffffff	0	0	Anaphylactic reaction due to vaccination	Contusion of left index finger with damage to nail	2023-06-03 15:04:34.461279	2023-06-03 15:04:34.461279
6	6	1	Gembucket	2	http://dummyimage.com/222x100.png/cc0000/ffffff	0	0	Nondisplaced associated transverse-posterior fracture of left acetabulum, subsequent encounter for fracture with nonunion	Other forms of systemic sclerosis	2023-06-03 15:04:34.508465	2023-06-03 15:04:34.508465
7	7	1	Sonair	1	http://dummyimage.com/141x100.png/ff4444/ffffff	0	0	Sprain of chondrosternal joint	Other fracture of fifth metacarpal bone, right hand, subsequent encounter for fracture with routine healing	2023-06-03 15:04:34.601632	2023-06-03 15:04:34.601632
8	8	1	Wrapsafe	2	http://dummyimage.com/205x100.png/cc0000/ffffff	0	0	Nondisplaced fracture of hook process of hamate [unciform] bone, left wrist, initial encounter for open fracture	Flail joint, left ankle and foot	2023-06-03 15:04:34.644964	2023-06-03 15:04:34.644964
9	9	1	Trippledex	1	http://dummyimage.com/220x100.png/ff4444/ffffff	0	0	Nondisplaced fracture of middle third of navicular [scaphoid] bone of right wrist, subsequent encounter for fracture with malunion	Exudative age-related macular degeneration, right eye, stage unspecified	2023-06-03 15:04:34.693612	2023-06-03 15:04:34.693612
10	10	1	Fix San	2	http://dummyimage.com/164x100.png/ff4444/ffffff	0	0	Displaced fracture of lesser trochanter of left femur, sequela	Unspecified injury of muscle(s) and tendon(s) of the rotator cuff of unspecified shoulder	2023-06-03 15:04:34.792292	2023-06-03 15:04:34.792292
11	11	1	Zamit	1	http://dummyimage.com/218x100.png/cc0000/ffffff	0	0	Salter-Harris Type II physeal fracture of lower end of unspecified tibia, initial encounter for closed fracture	Military operations involving explosion of improvised explosive device [IED], military personnel	2023-06-03 15:04:34.835186	2023-06-03 15:04:34.835186
12	12	1	Sub-Ex	1	http://dummyimage.com/133x100.png/ff4444/ffffff	0	0	Poisoning by tricyclic antidepressants, accidental (unintentional), sequela	Complete lesion at C2 level of cervical spinal cord, subsequent encounter	2023-06-03 15:04:34.885794	2023-06-03 15:04:34.885794
13	13	1	Matsoft	3	http://dummyimage.com/138x100.png/5fa2dd/ffffff	0	0	War operations involving friendly fire, sequela	Nondisplaced fracture of first metatarsal bone, right foot, initial encounter for closed fracture	2023-06-03 15:04:35.149345	2023-06-03 15:04:35.149345
14	14	1	Viva	2	http://dummyimage.com/180x100.png/5fa2dd/ffffff	0	0	Laceration of other blood vessels at lower leg level	Salter-Harris Type I physeal fracture of phalanx of unspecified toe, initial encounter for closed fracture	2023-06-03 15:04:35.195609	2023-06-03 15:04:35.195609
15	15	1	Asoka	3	http://dummyimage.com/142x100.png/dddddd/000000	0	0	External constriction of right back wall of thorax	Exposure to sudden change in air pressure in aircraft during descent, initial encounter	2023-06-03 15:04:35.247786	2023-06-03 15:04:35.247786
16	16	1	Transcof	2	http://dummyimage.com/232x100.png/ff4444/ffffff	0	0	Laceration with foreign body of right great toe without damage to nail, sequela	Salter-Harris Type II physeal fracture of unspecified metatarsal	2023-06-03 15:04:35.296579	2023-06-03 15:04:35.296579
17	17	1	Regrant	1	http://dummyimage.com/128x100.png/ff4444/ffffff	0	0	Puncture wound with foreign body of right middle finger with damage to nail, subsequent encounter	Poisoning by antiasthmatics, intentional self-harm	2023-06-03 15:04:35.338291	2023-06-03 15:04:35.338291
18	18	1	Konklab	3	http://dummyimage.com/231x100.png/5fa2dd/ffffff	0	0	Drug-induced chronic gout, unspecified shoulder	Nondisplaced fracture of left tibial tuberosity, subsequent encounter for open fracture type I or II with malunion	2023-06-03 15:04:35.391234	2023-06-03 15:04:35.391234
19	19	1	Mat Lam Tam	3	http://dummyimage.com/228x100.png/dddddd/000000	0	0	Displaced fracture of greater tuberosity of unspecified humerus, sequela	Follicular lymphoma grade IIIa, intrathoracic lymph nodes	2023-06-03 15:04:35.433267	2023-06-03 15:04:35.433267
20	20	1	Toughjoyfax	1	http://dummyimage.com/172x100.png/cc0000/ffffff	0	0	Pressure ulcer of unspecified site, stage 2	Displaced comminuted fracture of shaft of ulna, right arm, subsequent encounter for closed fracture with malunion	2023-06-03 15:04:35.586609	2023-06-03 15:04:35.586609
21	1	2	Zontrax	2	http://dummyimage.com/177x100.png/cc0000/ffffff	0	0	Nondisplaced segmental fracture of shaft of right fibula, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with delayed healing	Other fracture of right patella, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with malunion	2023-06-03 15:04:35.633509	2023-06-03 15:04:35.633509
22	2	2	Redhold	2	http://dummyimage.com/197x100.png/dddddd/000000	0	0	Motorcycle rider (driver) (passenger) injured in unspecified nontraffic accident, sequela	Unspecified subluxation of left middle finger	2023-06-03 15:04:35.683816	2023-06-03 15:04:35.683816
23	3	2	Trippledex	2	http://dummyimage.com/209x100.png/ff4444/ffffff	0	0	Salter-Harris Type IV physeal fracture of upper end of radius	Traumatic hemorrhage of cerebrum, unspecified, without loss of consciousness, subsequent encounter	2023-06-03 15:04:35.783118	2023-06-03 15:04:35.783118
24	4	2	Y-Solowarm	1	http://dummyimage.com/166x100.png/cc0000/ffffff	0	0	Minor laceration of celiac artery	Congenital stenosis and stricture of esophagus	2023-06-03 15:04:35.830159	2023-06-03 15:04:35.830159
25	5	2	Trippledex	3	http://dummyimage.com/214x100.png/dddddd/000000	0	0	Unspecified fracture of unspecified toe(s), subsequent encounter for fracture with malunion	Epileptic spasms, intractable, with status epilepticus	2023-06-03 15:04:35.873897	2023-06-03 15:04:35.873897
26	6	2	Tresom	3	http://dummyimage.com/149x100.png/dddddd/000000	0	0	Laceration without foreign body of right upper arm	Nondisplaced spiral fracture of shaft of unspecified femur, subsequent encounter for open fracture type I or II with nonunion	2023-06-03 15:04:35.921231	2023-06-03 15:04:35.921231
27	7	2	Holdlamis	1	http://dummyimage.com/146x100.png/dddddd/000000	0	0	Skin transplant status	Nondisplaced comminuted fracture of shaft of left fibula, subsequent encounter for open fracture type I or II with nonunion	2023-06-03 15:04:35.964735	2023-06-03 15:04:35.964735
28	8	2	Flexidy	2	http://dummyimage.com/122x100.png/5fa2dd/ffffff	0	0	Sprain of unspecified acromioclavicular joint	Underdosing of unspecified systemic anti-infectives and antiparasitics	2023-06-03 15:04:36.009586	2023-06-03 15:04:36.009586
29	9	2	Span	2	http://dummyimage.com/143x100.png/cc0000/ffffff	0	0	Displaced fracture of capitate [os magnum] bone, right wrist, subsequent encounter for fracture with nonunion	Postprocedural seroma of skin and subcutaneous tissue following a dermatologic procedure	2023-06-03 15:04:36.059337	2023-06-03 15:04:36.059337
30	10	2	Voltsillam	3	http://dummyimage.com/144x100.png/5fa2dd/ffffff	0	0	Drowning and submersion due to other accident to sailboat	Other specified disorders of nose and nasal sinuses	2023-06-03 15:04:36.118299	2023-06-03 15:04:36.118299
31	11	2	Veribet	3	http://dummyimage.com/179x100.png/dddddd/000000	0	0	Nondisplaced fracture of proximal phalanx of left great toe, sequela	Edema, not elsewhere classified	2023-06-03 15:04:36.17097	2023-06-03 15:04:36.17097
32	12	2	Zaam-Dox	1	http://dummyimage.com/215x100.png/cc0000/ffffff	0	0	Bitten by other mammals	Incarcerated fracture (avulsion) of medial epicondyle of unspecified humerus, subsequent encounter for fracture with nonunion	2023-06-03 15:04:36.21486	2023-06-03 15:04:36.21486
33	13	2	Bitchip	1	http://dummyimage.com/157x100.png/5fa2dd/ffffff	0	0	Displaced fracture of neck of fourth metacarpal bone, right hand, subsequent encounter for fracture with nonunion	Chorioretinal scars	2023-06-03 15:04:36.262543	2023-06-03 15:04:36.262543
34	14	2	Temp	2	http://dummyimage.com/159x100.png/ff4444/ffffff	0	0	Crushing injury of left ring finger	Other fracture of unspecified lesser toe(s), initial encounter for closed fracture	2023-06-03 15:04:36.365171	2023-06-03 15:04:36.365171
35	15	2	Fix San	1	http://dummyimage.com/186x100.png/cc0000/ffffff	0	0	Diabetes mellitus due to underlying condition with hyperosmolarity without nonketotic hyperglycemic-hyperosmolar coma (NKHHC)	Cerebral infarction due to thrombosis of cerebellar artery	2023-06-03 15:04:36.416763	2023-06-03 15:04:36.416763
36	16	2	Quo Lux	1	http://dummyimage.com/225x100.png/ff4444/ffffff	0	0	Nondisplaced fracture of posterior column [ilioischial] of unspecified acetabulum, subsequent encounter for fracture with routine healing	Frostbite with tissue necrosis of left hand, initial encounter	2023-06-03 15:04:36.465744	2023-06-03 15:04:36.465744
37	17	2	Kanlam	2	http://dummyimage.com/146x100.png/dddddd/000000	0	0	Nondisplaced avulsion fracture of unspecified ilium, subsequent encounter for fracture with routine healing	Other anterior dislocation of left hip, sequela	2023-06-03 15:04:36.512604	2023-06-03 15:04:36.512604
38	18	2	Biodex	2	http://dummyimage.com/151x100.png/5fa2dd/ffffff	0	0	Unspecified injury of muscle and tendon of long extensor muscle of toe at ankle and foot level, right foot	Poisoning by, adverse effect of and underdosing of other nonsteroidal anti-inflammatory drugs [NSAID]	2023-06-03 15:04:36.562338	2023-06-03 15:04:36.562338
39	19	2	Tempsoft	3	http://dummyimage.com/123x100.png/ff4444/ffffff	0	0	Non-pressure chronic ulcer of other part of right foot	Poisoning by other viral vaccines, accidental (unintentional), initial encounter	2023-06-03 15:04:36.606221	2023-06-03 15:04:36.606221
40	20	2	Flowdesk	2	http://dummyimage.com/135x100.png/cc0000/ffffff	0	0	Adverse effect of other narcotics, sequela	Unspecified fracture of third metacarpal bone, left hand, subsequent encounter for fracture with delayed healing	2023-06-03 15:04:36.654261	2023-06-03 15:04:36.654261
41	1	3	Veribet	2	http://dummyimage.com/100x100.png/5fa2dd/ffffff	0	0	Earthquake, initial encounter	Unspecified otitis externa, bilateral	2023-06-03 15:04:36.711874	2023-06-03 15:04:36.711874
42	2	3	Andalax	3	http://dummyimage.com/181x100.png/cc0000/ffffff	0	0	Underdosing of 4-Aminophenol derivatives, subsequent encounter	Neurosyphilis, unspecified	2023-06-03 15:04:36.7573	2023-06-03 15:04:36.7573
43	3	3	Lotlux	2	http://dummyimage.com/194x100.png/5fa2dd/ffffff	0	0	Unspecified fracture of left ilium, initial encounter for closed fracture	Nondisplaced oblique fracture of shaft of left fibula, subsequent encounter for closed fracture with malunion	2023-06-03 15:04:36.806342	2023-06-03 15:04:36.806342
44	4	3	Pannier	2	http://dummyimage.com/141x100.png/ff4444/ffffff	0	0	Adverse effect of other drugs, medicaments and biological substances	Mechanical lagophthalmos right upper eyelid	2023-06-03 15:04:36.871335	2023-06-03 15:04:36.871335
45	5	3	Toughjoyfax	3	http://dummyimage.com/178x100.png/dddddd/000000	0	0	Contusion of right great toe without damage to nail	Complete traumatic amputation of unspecified breast, subsequent encounter	2023-06-03 15:04:36.917377	2023-06-03 15:04:36.917377
46	6	3	Fixflex	2	http://dummyimage.com/132x100.png/cc0000/ffffff	0	0	Other fracture of upper end of unspecified ulna, subsequent encounter for closed fracture with nonunion	Contusion of left knee, subsequent encounter	2023-06-03 15:04:36.969051	2023-06-03 15:04:36.969051
47	7	3	Stronghold	1	http://dummyimage.com/177x100.png/dddddd/000000	0	0	Driver of bus injured in collision with car, pick-up truck or van in traffic accident, subsequent encounter	Nondisplaced fracture of left ulna styloid process, subsequent encounter for closed fracture with routine healing	2023-06-03 15:04:37.013301	2023-06-03 15:04:37.013301
48	8	3	Treeflex	1	http://dummyimage.com/118x100.png/ff4444/ffffff	0	0	Other fracture of lower end of left ulna, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with malunion	Polyhydramnios, unspecified trimester, not applicable or unspecified	2023-06-03 15:04:37.059156	2023-06-03 15:04:37.059156
49	9	3	Bigtax	2	http://dummyimage.com/150x100.png/dddddd/000000	0	0	Displaced fracture of neck of right radius, subsequent encounter for closed fracture with nonunion	Contact with contaminated hypodermic needle	2023-06-03 15:04:37.103149	2023-06-03 15:04:37.103149
50	10	3	Home Ing	2	http://dummyimage.com/147x100.png/dddddd/000000	0	0	Leakage of surgically created arteriovenous fistula	Other specified urinary incontinence	2023-06-03 15:04:37.149148	2023-06-03 15:04:37.149148
51	11	3	Zamit	1	http://dummyimage.com/117x100.png/5fa2dd/ffffff	0	0	Intraventricular (nontraumatic) hemorrhage, grade 4, of newborn	Displaced fracture of proximal phalanx of right great toe, sequela	2023-06-03 15:04:37.205024	2023-06-03 15:04:37.205024
52	12	3	Stim	1	http://dummyimage.com/208x100.png/dddddd/000000	0	0	Nondisplaced fracture of neck of unspecified talus, initial encounter for open fracture	Other atherosclerosis of native arteries of extremities	2023-06-03 15:04:37.263175	2023-06-03 15:04:37.263175
53	13	3	Lotstring	1	http://dummyimage.com/233x100.png/5fa2dd/ffffff	0	0	Toxic effect of venom of wasps, assault, initial encounter	Infection of amputation stump, left upper extremity	2023-06-03 15:04:37.309957	2023-06-03 15:04:37.309957
54	14	3	Holdlamis	3	http://dummyimage.com/170x100.png/cc0000/ffffff	0	0	Fall on same level from slipping, tripping and stumbling	Displaced longitudinal fracture of unspecified patella, subsequent encounter for closed fracture with routine healing	2023-06-03 15:04:37.361701	2023-06-03 15:04:37.361701
55	15	3	Transcof	1	http://dummyimage.com/185x100.png/cc0000/ffffff	0	0	Toxic effect of other specified inorganic substances, assault	Unspecified injury of other blood vessels at forearm level, left arm, sequela	2023-06-03 15:04:37.421004	2023-06-03 15:04:37.421004
56	16	3	Stringtough	2	http://dummyimage.com/204x100.png/cc0000/ffffff	0	0	Other fracture of upper end of unspecified ulna, subsequent encounter for open fracture type I or II with delayed healing	Nondisplaced fracture of proximal phalanx of unspecified finger, initial encounter for closed fracture	2023-06-03 15:04:37.47032	2023-06-03 15:04:37.47032
57	17	3	Opela	1	http://dummyimage.com/125x100.png/dddddd/000000	0	0	Contusion and laceration of left cerebrum with loss of consciousness greater than 24 hours without return to pre-existing conscious level with patient surviving	Laceration without foreign body of abdominal wall, periumbilic region without penetration into peritoneal cavity, initial encounter	2023-06-03 15:04:37.730417	2023-06-03 15:04:37.730417
58	18	3	Alpha	2	http://dummyimage.com/141x100.png/cc0000/ffffff	0	0	Unspecified occupant of bus injured in collision with railway train or railway vehicle in traffic accident	Underdosing of unspecified anesthetics	2023-06-03 15:04:37.798851	2023-06-03 15:04:37.798851
59	19	3	Hatity	2	http://dummyimage.com/116x100.png/dddddd/000000	0	0	Other mechanical complication of implanted electronic neurostimulator of peripheral nerve electrode (lead)	Ulceration of vagina	2023-06-03 15:04:37.846957	2023-06-03 15:04:37.846957
60	20	3	Zaam-Dox	2	http://dummyimage.com/238x100.png/ff4444/ffffff	0	0	Superficial frostbite of unspecified wrist, sequela	Malignant neoplasm of axillary tail of right male breast	2023-06-03 15:04:37.901359	2023-06-03 15:04:37.901359
61	1	4	Alphazap	3	http://dummyimage.com/186x100.png/5fa2dd/ffffff	0	0	Flail joint, right hip	Nondisplaced fracture of lunate [semilunar], unspecified wrist, subsequent encounter for fracture with malunion	2023-06-03 15:04:37.946949	2023-06-03 15:04:37.946949
62	2	4	Regrant	3	http://dummyimage.com/111x100.png/dddddd/000000	0	0	Other gonococcal eye infection	Drowning and submersion due to fall off water-skis	2023-06-03 15:04:37.998054	2023-06-03 15:04:37.998054
63	3	4	Voltsillam	2	http://dummyimage.com/202x100.png/cc0000/ffffff	0	0	Stress fracture, right fibula, subsequent encounter for fracture with nonunion	Unspecified sprain of left little finger, subsequent encounter	2023-06-03 15:04:38.052563	2023-06-03 15:04:38.052563
64	4	4	Fintone	2	http://dummyimage.com/243x100.png/5fa2dd/ffffff	0	0	Strain of unspecified muscle, fascia and tendon at shoulder and upper arm level, left arm, subsequent encounter	Balloon fire injuring occupant	2023-06-03 15:04:38.098167	2023-06-03 15:04:38.098167
65	5	4	Treeflex	1	http://dummyimage.com/249x100.png/cc0000/ffffff	0	0	Displaced fracture of body of unspecified talus, subsequent encounter for fracture with nonunion	Posterior cyclitis, left eye	2023-06-03 15:04:38.162499	2023-06-03 15:04:38.162499
66	6	4	Namfix	1	http://dummyimage.com/231x100.png/dddddd/000000	0	0	Terrorism involving firearms, civilian injured, subsequent encounter	Displaced fracture of posterior process of unspecified talus	2023-06-03 15:04:38.238976	2023-06-03 15:04:38.238976
67	7	4	Stronghold	2	http://dummyimage.com/155x100.png/5fa2dd/ffffff	0	0	Subluxation of unspecified thoracic vertebra, sequela	Injury of blood vessel of thumb	2023-06-03 15:04:38.284814	2023-06-03 15:04:38.284814
68	8	4	Andalax	3	http://dummyimage.com/213x100.png/dddddd/000000	0	0	Nondisplaced fracture of coronoid process of unspecified ulna, subsequent encounter for closed fracture with nonunion	Infective myositis, unspecified forearm	2023-06-03 15:04:38.333002	2023-06-03 15:04:38.333002
69	9	4	Greenlam	1	http://dummyimage.com/210x100.png/ff4444/ffffff	0	0	Other intraarticular fracture of lower end of right radius, subsequent encounter for closed fracture with nonunion	Nondisplaced fracture of greater tuberosity of left humerus, subsequent encounter for fracture with nonunion	2023-06-03 15:04:38.373903	2023-06-03 15:04:38.373903
70	10	4	Tresom	2	http://dummyimage.com/133x100.png/ff4444/ffffff	0	0	Postpartum inversion of uterus	Exposure to sudden change in air pressure in aircraft during ascent	2023-06-03 15:04:38.41832	2023-06-03 15:04:38.41832
71	11	4	Tempsoft	2	http://dummyimage.com/244x100.png/cc0000/ffffff	0	0	Arthropathies in other specified diseases classified elsewhere, left wrist	Displaced articular fracture of head of right femur, subsequent encounter for open fracture type I or II with routine healing	2023-06-03 15:04:38.464044	2023-06-03 15:04:38.464044
72	12	4	Stim	1	http://dummyimage.com/174x100.png/cc0000/ffffff	0	0	Other injury of other extensor muscle, fascia and tendon at forearm level, left arm, subsequent encounter	Nondisplaced transverse fracture of shaft of left radius, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with nonunion	2023-06-03 15:04:38.570948	2023-06-03 15:04:38.570948
73	13	4	Ronstring	3	http://dummyimage.com/125x100.png/dddddd/000000	0	0	Other mechanical complication of implanted electronic neurostimulator of peripheral nerve electrode (lead)	Partial traumatic amputation at knee level	2023-06-03 15:04:38.618818	2023-06-03 15:04:38.618818
74	14	4	Y-Solowarm	1	http://dummyimage.com/135x100.png/cc0000/ffffff	0	0	Contusion and laceration of right cerebrum with loss of consciousness of any duration with death due to other cause prior to regaining consciousness, initial encounter	Lead-induced chronic gout, left shoulder	2023-06-03 15:04:38.746963	2023-06-03 15:04:38.746963
75	15	4	Zamit	2	http://dummyimage.com/226x100.png/dddddd/000000	0	0	Stress fracture, unspecified tibia and fibula, sequela	Unspecified occupant of three-wheeled motor vehicle injured in collision with railway train or railway vehicle in traffic accident, sequela	2023-06-03 15:04:38.793454	2023-06-03 15:04:38.793454
76	16	4	Hatity	2	http://dummyimage.com/226x100.png/dddddd/000000	0	0	Alzheimer's disease	Mansonelliasis	2023-06-03 15:04:38.874045	2023-06-03 15:04:38.874045
77	17	4	Wrapsafe	3	http://dummyimage.com/179x100.png/ff4444/ffffff	0	0	Contact with and (suspected) exposure to other environmental pollution	Unspecified occupant of special industrial vehicle injured in nontraffic accident, sequela	2023-06-03 15:04:38.917611	2023-06-03 15:04:38.917611
78	18	4	Flexidy	1	http://dummyimage.com/108x100.png/dddddd/000000	0	0	Passenger on bus injured in collision with other nonmotor vehicle in nontraffic accident, subsequent encounter	Motorcycle driver injured in collision with pedestrian or animal in traffic accident	2023-06-03 15:04:38.958744	2023-06-03 15:04:38.958744
79	19	4	Fixflex	3	http://dummyimage.com/142x100.png/cc0000/ffffff	0	0	Accidental puncture and laceration of a circulatory system organ or structure during a procedure	Agenesis, aplasia and hypoplasia of gallbladder	2023-06-03 15:04:39.003481	2023-06-03 15:04:39.003481
80	20	4	Bamity	2	http://dummyimage.com/125x100.png/5fa2dd/ffffff	0	0	Unspecified fracture of the lower end of unspecified radius, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with delayed healing	Blue sclera	2023-06-03 15:04:39.050942	2023-06-03 15:04:39.050942
81	1	5	Cardguard	3	http://dummyimage.com/228x100.png/dddddd/000000	0	0	Displaced bicondylar fracture of unspecified tibia	Displaced other fracture of tuberosity of right calcaneus, initial encounter for open fracture	2023-06-03 15:04:39.099466	2023-06-03 15:04:39.099466
82	2	5	Redhold	3	http://dummyimage.com/130x100.png/cc0000/ffffff	0	0	Nondisplaced fracture of distal phalanx of right index finger, subsequent encounter for fracture with delayed healing	Type I occipital condyle fracture, unspecified side, initial encounter for closed fracture	2023-06-03 15:04:39.14879	2023-06-03 15:04:39.14879
83	3	5	Kanlam	3	http://dummyimage.com/167x100.png/ff4444/ffffff	0	0	Other specified injury of unspecified blood vessel at shoulder and upper arm level, right arm, subsequent encounter	Postimmunization arthropathy, vertebrae	2023-06-03 15:04:39.19393	2023-06-03 15:04:39.19393
84	4	5	Hatity	3	http://dummyimage.com/196x100.png/5fa2dd/ffffff	0	0	Nondisplaced fracture of second metatarsal bone, unspecified foot, subsequent encounter for fracture with nonunion	Idiopathic chronic gout, right elbow, without tophus (tophi)	2023-06-03 15:04:39.244957	2023-06-03 15:04:39.244957
85	5	5	Stim	3	http://dummyimage.com/180x100.png/dddddd/000000	0	0	Displacement of other bone devices, implants and grafts, subsequent encounter	Nondisplaced unspecified fracture of left great toe	2023-06-03 15:04:39.299142	2023-06-03 15:04:39.299142
86	6	5	Fintone	2	http://dummyimage.com/228x100.png/ff4444/ffffff	0	0	Dislocation of metacarpophalangeal joint of left thumb	Nonrheumatic aortic (valve) insufficiency	2023-06-03 15:04:39.372766	2023-06-03 15:04:39.372766
87	7	5	Bitwolf	1	http://dummyimage.com/180x100.png/cc0000/ffffff	0	0	Salter-Harris Type IV physeal fracture of phalanx of left toe, initial encounter for closed fracture	Unspecified fracture of T11-T12 vertebra, subsequent encounter for fracture with delayed healing	2023-06-03 15:04:39.428109	2023-06-03 15:04:39.428109
88	8	5	Tampflex	1	http://dummyimage.com/209x100.png/5fa2dd/ffffff	0	0	Erythema multiforme	Essential (hemorrhagic) thrombocythemia	2023-06-03 15:04:39.476213	2023-06-03 15:04:39.476213
89	9	5	Biodex	3	http://dummyimage.com/244x100.png/cc0000/ffffff	0	0	Opioid dependence with opioid-induced sexual dysfunction	Poisoning by coronary vasodilators, assault, subsequent encounter	2023-06-03 15:04:39.538942	2023-06-03 15:04:39.538942
90	10	5	Alpha	2	http://dummyimage.com/244x100.png/cc0000/ffffff	0	0	Unspecified injury of intrinsic muscle and tendon at ankle and foot level, left foot	Malignant neoplasm of short bones of left upper limb	2023-06-03 15:04:39.584115	2023-06-03 15:04:39.584115
91	11	5	Solarbreeze	1	http://dummyimage.com/234x100.png/dddddd/000000	0	0	Sprain of metacarpophalangeal joint of left middle finger, subsequent encounter	Pathological fracture in neoplastic disease, right ulna, sequela	2023-06-03 15:04:39.627079	2023-06-03 15:04:39.627079
92	12	5	Veribet	2	http://dummyimage.com/162x100.png/dddddd/000000	0	0	Toxic effect of other specified noxious substances eaten as food, assault, initial encounter	Familial chondrocalcinosis, knee	2023-06-03 15:04:39.6756	2023-06-03 15:04:39.6756
93	13	5	Greenlam	2	http://dummyimage.com/136x100.png/5fa2dd/ffffff	0	0	Person injured in collision between heavy transport vehicle and bus, nontraffic, sequela	Burn of first degree of unspecified lower leg, sequela	2023-06-03 15:04:39.739074	2023-06-03 15:04:39.739074
94	14	5	Namfix	3	http://dummyimage.com/118x100.png/cc0000/ffffff	0	0	Partial traumatic amputation of female external genital organs, sequela	Brown-Sequard syndrome at C2 level of cervical spinal cord, subsequent encounter	2023-06-03 15:04:39.822738	2023-06-03 15:04:39.822738
95	15	5	Prodder	1	http://dummyimage.com/189x100.png/ff4444/ffffff	0	0	Smith's fracture of left radius, subsequent encounter for closed fracture with routine healing	Fracture of unspecified phalanx of left little finger, subsequent encounter for fracture with malunion	2023-06-03 15:04:39.931994	2023-06-03 15:04:39.931994
96	16	5	Daltfresh	3	http://dummyimage.com/167x100.png/cc0000/ffffff	0	0	Acute embolism and thrombosis of unspecified veins of unspecified upper extremity	Pain in right arm	2023-06-03 15:04:39.975001	2023-06-03 15:04:39.975001
97	17	5	Zamit	1	http://dummyimage.com/123x100.png/5fa2dd/ffffff	0	0	Chronic radiodermatitis	Injury of digital nerve of right ring finger, sequela	2023-06-03 15:04:40.032904	2023-06-03 15:04:40.032904
98	18	5	Job	2	http://dummyimage.com/216x100.png/cc0000/ffffff	0	0	Injury of femoral nerve at hip and thigh level, right leg, subsequent encounter	Driver of bus injured in collision with heavy transport vehicle or bus in traffic accident, sequela	2023-06-03 15:04:40.074152	2023-06-03 15:04:40.074152
99	19	5	Lotlux	1	http://dummyimage.com/224x100.png/5fa2dd/ffffff	0	0	Occupant of pick-up truck or van injured in collision with pedestrian or animal	Burn of first degree of neck, sequela	2023-06-03 15:04:40.123222	2023-06-03 15:04:40.123222
100	20	5	Y-find	1	http://dummyimage.com/239x100.png/cc0000/ffffff	0	0	Subluxation of proximal interphalangeal joint of right thumb	Open bite of left thumb without damage to nail, initial encounter	2023-06-03 15:04:40.164958	2023-06-03 15:04:40.164958
101	1	6	Sonair	3	http://dummyimage.com/243x100.png/5fa2dd/ffffff	0	0	Nondisplaced fracture of lateral malleolus of left fibula, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	Other specified inflammatory spondylopathies, thoracolumbar region	2023-06-03 15:04:40.218574	2023-06-03 15:04:40.218574
102	2	6	Kanlam	2	http://dummyimage.com/130x100.png/dddddd/000000	0	0	Person on outside of pick-up truck or van injured in collision with fixed or stationary object in nontraffic accident	Unspecified fracture of unspecified femur, initial encounter for open fracture type IIIA, IIIB, or IIIC	2023-06-03 15:04:40.270964	2023-06-03 15:04:40.270964
103	3	6	Lotstring	1	http://dummyimage.com/219x100.png/ff4444/ffffff	0	0	Arthritis due to other bacteria, elbow	Intervertebral disc stenosis of neural canal of cervical region	2023-06-03 15:04:40.338767	2023-06-03 15:04:40.338767
104	4	6	Redhold	3	http://dummyimage.com/132x100.png/cc0000/ffffff	0	0	Nondisplaced fracture of distal phalanx of unspecified great toe, initial encounter for open fracture	Laceration with foreign body of left thumb without damage to nail, sequela	2023-06-03 15:04:40.445227	2023-06-03 15:04:40.445227
105	5	6	Keylex	3	http://dummyimage.com/104x100.png/cc0000/ffffff	0	0	Traumatic subdural hemorrhage with loss of consciousness of 31 minutes to 59 minutes, subsequent encounter	Insect bite (nonvenomous) of left little finger, sequela	2023-06-03 15:04:40.621877	2023-06-03 15:04:40.621877
106	6	6	Keylex	1	http://dummyimage.com/106x100.png/ff4444/ffffff	0	0	Unspecified injury of unspecified blood vessel at ankle and foot level, unspecified leg	Nondisplaced fracture of shaft of right clavicle, sequela	2023-06-03 15:04:41.13502	2023-06-03 15:04:41.13502
107	7	6	Latlux	3	http://dummyimage.com/128x100.png/cc0000/ffffff	0	0	Nipple discharge	Osteochondrosis (juvenile) of metacarpal heads [Mauclaire], right hand	2023-06-03 15:04:41.180502	2023-06-03 15:04:41.180502
108	8	6	Vagram	1	http://dummyimage.com/177x100.png/ff4444/ffffff	0	0	Other complications specific to multiple gestation	Adverse effect of anticholinesterase agents, subsequent encounter	2023-06-03 15:04:41.230452	2023-06-03 15:04:41.230452
109	9	6	Cookley	1	http://dummyimage.com/164x100.png/5fa2dd/ffffff	0	0	Other specified disorders of Eustachian tube, left ear	Other secondary chronic gout, left shoulder, with tophus (tophi)	2023-06-03 15:04:41.306308	2023-06-03 15:04:41.306308
110	10	6	Solarbreeze	3	http://dummyimage.com/138x100.png/dddddd/000000	0	0	Complete lesion at T11-T12 level of thoracic spinal cord	Legal intervention involving other specified means	2023-06-03 15:04:41.36278	2023-06-03 15:04:41.36278
111	11	6	Veribet	1	http://dummyimage.com/127x100.png/cc0000/ffffff	0	0	Contusion and laceration of cerebrum, unspecified, with loss of consciousness of unspecified duration, initial encounter	Unspecified fracture of shaft of right fibula, subsequent encounter for open fracture type I or II with nonunion	2023-06-03 15:04:41.489971	2023-06-03 15:04:41.489971
112	12	6	Cardify	3	http://dummyimage.com/241x100.png/5fa2dd/ffffff	0	0	Localized swelling, mass and lump, right lower limb	Person on outside of heavy transport vehicle injured in collision with heavy transport vehicle or bus in nontraffic accident, subsequent encounter	2023-06-03 15:04:41.543358	2023-06-03 15:04:41.543358
113	13	6	Y-Solowarm	3	http://dummyimage.com/186x100.png/cc0000/ffffff	0	0	Idiopathic chronic gout, unspecified wrist, with tophus (tophi)	Loose body in knee, left knee	2023-06-03 15:04:41.735079	2023-06-03 15:04:41.735079
114	14	6	Asoka	1	http://dummyimage.com/139x100.png/dddddd/000000	0	0	Hit by object from burning building or structure in uncontrolled fire	Fracture of unspecified metatarsal bone(s), unspecified foot, sequela	2023-06-03 15:04:41.836217	2023-06-03 15:04:41.836217
115	15	6	Bitwolf	3	http://dummyimage.com/119x100.png/ff4444/ffffff	0	0	Traumatic rupture of right radiocarpal ligament, subsequent encounter	Sezary disease, lymph nodes of head, face, and neck	2023-06-03 15:04:41.934326	2023-06-03 15:04:41.934326
116	16	6	Bytecard	1	http://dummyimage.com/129x100.png/5fa2dd/ffffff	0	0	Nondisplaced fracture of first metatarsal bone, unspecified foot, subsequent encounter for fracture with delayed healing	Puncture wound with foreign body of left little finger without damage to nail, subsequent encounter	2023-06-03 15:04:42.034586	2023-06-03 15:04:42.034586
117	17	6	Alpha	3	http://dummyimage.com/234x100.png/5fa2dd/ffffff	0	0	Diagnostic and monitoring physical medicine devices associated with adverse incidents	Ulcerative colitis, unspecified with unspecified complications	2023-06-03 15:04:42.134639	2023-06-03 15:04:42.134639
118	18	6	Stim	2	http://dummyimage.com/157x100.png/cc0000/ffffff	0	0	Nondisplaced intertrochanteric fracture of unspecified femur	Unspecified injury of muscle and tendon of back wall of thorax, sequela	2023-06-03 15:04:42.179991	2023-06-03 15:04:42.179991
119	19	6	Home Ing	2	http://dummyimage.com/217x100.png/cc0000/ffffff	0	0	Sprain of unspecified sternoclavicular joint	Varicella pneumonia	2023-06-03 15:04:42.234348	2023-06-03 15:04:42.234348
120	20	6	Latlux	2	http://dummyimage.com/218x100.png/dddddd/000000	0	0	Poisoning by unspecified primarily systemic and hematological agent, assault, subsequent encounter	Hematemesis	2023-06-03 15:04:42.334611	2023-06-03 15:04:42.334611
121	1	7	Trippledex	1	http://dummyimage.com/106x100.png/ff4444/ffffff	0	0	Persistent migraine aura with cerebral infarction, not intractable, with status migrainosus	Military operations involving explosion of aerial bomb, military personnel, subsequent encounter	2023-06-03 15:04:42.436726	2023-06-03 15:04:42.436726
122	2	7	Bytecard	3	http://dummyimage.com/103x100.png/ff4444/ffffff	0	0	Burn of third degree of multiple right fingers (nail), not including thumb	Unspecified fracture of unspecified metacarpal bone, initial encounter for closed fracture	2023-06-03 15:04:42.534328	2023-06-03 15:04:42.534328
123	3	7	Y-find	2	http://dummyimage.com/134x100.png/5fa2dd/ffffff	0	0	Strain of muscle and tendon of unspecified wall of thorax	Displaced fracture of base of neck of unspecified femur, subsequent encounter for closed fracture with delayed healing	2023-06-03 15:04:42.634744	2023-06-03 15:04:42.634744
124	4	7	Lotlux	3	http://dummyimage.com/119x100.png/ff4444/ffffff	0	0	Chondromalacia, joints of right hand	External constriction of right ear, sequela	2023-06-03 15:04:42.734324	2023-06-03 15:04:42.734324
125	5	7	Treeflex	3	http://dummyimage.com/212x100.png/dddddd/000000	0	0	Salter-Harris Type I physeal fracture of upper end of tibia	Corrosion of unspecified degree of scapular region	2023-06-03 15:04:42.834328	2023-06-03 15:04:42.834328
126	6	7	Zamit	1	http://dummyimage.com/124x100.png/dddddd/000000	0	0	Other injury of flexor muscle, fascia and tendon of left little finger at forearm level, subsequent encounter	Monoplegia of upper limb following unspecified cerebrovascular disease affecting unspecified side	2023-06-03 15:04:42.934325	2023-06-03 15:04:42.934325
127	7	7	Fix San	1	http://dummyimage.com/131x100.png/dddddd/000000	0	0	Nondisplaced transverse fracture of shaft of left radius, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with delayed healing	Corrosion of second degree of multiple sites of head, face, and neck	2023-06-03 15:04:43.034331	2023-06-03 15:04:43.034331
128	8	7	Home Ing	3	http://dummyimage.com/124x100.png/5fa2dd/ffffff	0	0	Unspecified occupant of pick-up truck or van injured in noncollision transport accident in nontraffic accident	Toxic effect of venom of centipedes and venomous millipedes, assault, subsequent encounter	2023-06-03 15:04:43.134328	2023-06-03 15:04:43.134328
129	9	7	Asoka	1	http://dummyimage.com/107x100.png/ff4444/ffffff	0	0	Toxic effect of unspecified pesticide, intentional self-harm	Displaced transverse fracture of unspecified patella, subsequent encounter for open fracture type I or II with malunion	2023-06-03 15:04:43.181085	2023-06-03 15:04:43.181085
130	10	7	Andalax	3	http://dummyimage.com/170x100.png/ff4444/ffffff	0	0	Bitten by other rodent, sequela	Open bite of left middle finger with damage to nail, sequela	2023-06-03 15:04:43.222174	2023-06-03 15:04:43.222174
131	11	7	Bitchip	1	http://dummyimage.com/237x100.png/dddddd/000000	0	0	Stenosis of unspecified lacrimal sac	Contusion of stomach, initial encounter	2023-06-03 15:04:43.264411	2023-06-03 15:04:43.264411
132	12	7	Cardify	3	http://dummyimage.com/208x100.png/cc0000/ffffff	0	0	Nondisplaced fracture of greater trochanter of unspecified femur, subsequent encounter for closed fracture with malunion	Hb-SS disease with crisis, unspecified	2023-06-03 15:04:43.308626	2023-06-03 15:04:43.308626
133	13	7	Stringtough	1	http://dummyimage.com/217x100.png/ff4444/ffffff	0	0	Poisoning by other anti-common-cold drugs, undetermined	Strain of flexor muscle, fascia and tendon of right little finger at wrist and hand level	2023-06-03 15:04:43.355316	2023-06-03 15:04:43.355316
134	14	7	Zontrax	1	http://dummyimage.com/178x100.png/5fa2dd/ffffff	0	0	Bariatric surgery status complicating pregnancy, unspecified trimester	Benign neoplasm of cornea	2023-06-03 15:04:43.412786	2023-06-03 15:04:43.412786
135	15	7	Wrapsafe	1	http://dummyimage.com/112x100.png/cc0000/ffffff	0	0	Drowning and submersion while in swimming pool, undetermined intent, initial encounter	Neoplasm of uncertain behavior of brain, unspecified	2023-06-03 15:04:43.457324	2023-06-03 15:04:43.457324
136	16	7	Alpha	2	http://dummyimage.com/140x100.png/dddddd/000000	0	0	Secondary pigmentary degeneration	Struck by crocodile	2023-06-03 15:04:43.510499	2023-06-03 15:04:43.510499
137	17	7	Keylex	3	http://dummyimage.com/181x100.png/dddddd/000000	0	0	Corrosion of second degree of right hand, unspecified site	Nondisplaced spiral fracture of shaft of left tibia, sequela	2023-06-03 15:04:43.581505	2023-06-03 15:04:43.581505
138	18	7	Tresom	3	http://dummyimage.com/216x100.png/ff4444/ffffff	0	0	Unspecified occupant of heavy transport vehicle injured in collision with car, pick-up truck or van in nontraffic accident, sequela	Other mental disorders complicating pregnancy, third trimester	2023-06-03 15:04:43.628104	2023-06-03 15:04:43.628104
139	19	7	Holdlamis	1	http://dummyimage.com/175x100.png/cc0000/ffffff	0	0	Unspecified injury of flexor muscle, fascia and tendon of right ring finger at wrist and hand level, subsequent encounter	Complete traumatic amputation at level between unspecified shoulder and elbow, initial encounter	2023-06-03 15:04:43.672877	2023-06-03 15:04:43.672877
140	20	7	Job	2	http://dummyimage.com/202x100.png/ff4444/ffffff	0	0	Pathological fracture in neoplastic disease, left humerus, subsequent encounter for fracture with malunion	Ocular laceration without prolapse or loss of intraocular tissue, left eye, subsequent encounter	2023-06-03 15:04:43.715227	2023-06-03 15:04:43.715227
141	1	8	Overhold	3	http://dummyimage.com/152x100.png/5fa2dd/ffffff	0	0	Other secondary chronic gout, left knee	Disseminated blastomycosis	2023-06-03 15:04:43.759988	2023-06-03 15:04:43.759988
142	2	8	Sonsing	2	http://dummyimage.com/180x100.png/cc0000/ffffff	0	0	Passenger of snowmobile injured in nontraffic accident, subsequent encounter	Strain of intrinsic muscle, fascia and tendon of unspecified thumb at wrist and hand level, sequela	2023-06-03 15:04:43.806756	2023-06-03 15:04:43.806756
143	3	8	Wrapsafe	3	http://dummyimage.com/155x100.png/cc0000/ffffff	0	0	Nondisplaced oblique fracture of shaft of unspecified fibula, sequela	Pedestrian on skateboard injured in collision with railway train or railway vehicle in traffic accident, sequela	2023-06-03 15:04:43.850225	2023-06-03 15:04:43.850225
144	4	8	Latlux	3	http://dummyimage.com/166x100.png/dddddd/000000	0	0	Pedal cycle driver injured in collision with pedestrian or animal in nontraffic accident, subsequent encounter	Unspecified fracture of shaft of right femur, sequela	2023-06-03 15:04:43.893098	2023-06-03 15:04:43.893098
145	5	8	Namfix	1	http://dummyimage.com/249x100.png/ff4444/ffffff	0	0	Activity, walking, marching and hiking	Toxic effect of rodenticides, undetermined, subsequent encounter	2023-06-03 15:04:43.945421	2023-06-03 15:04:43.945421
146	6	8	Zoolab	2	http://dummyimage.com/221x100.png/dddddd/000000	0	0	Poisoning by lysergide [LSD], accidental (unintentional), subsequent encounter	Nondisplaced fracture of neck of scapula, unspecified shoulder, subsequent encounter for fracture with nonunion	2023-06-03 15:04:43.991841	2023-06-03 15:04:43.991841
263	3	14	Regrant	1	http://dummyimage.com/116x100.png/5fa2dd/ffffff	0	0	Pressure ulcer of left elbow, stage 2	Early syphilis	2023-06-03 15:04:50.546989	2023-06-03 15:04:50.546989
147	7	8	Holdlamis	2	http://dummyimage.com/128x100.png/cc0000/ffffff	0	0	Military operations involving chemical weapons and other forms of unconventional warfare, civilian	Poisoning by hydantoin derivatives, accidental (unintentional), sequela	2023-06-03 15:04:44.046158	2023-06-03 15:04:44.046158
148	8	8	Bitwolf	1	http://dummyimage.com/205x100.png/cc0000/ffffff	0	0	Fracture of unspecified phalanx of other finger, subsequent encounter for fracture with routine healing	Age-related osteoporosis with current pathological fracture, unspecified ankle and foot, initial encounter for fracture	2023-06-03 15:04:44.100302	2023-06-03 15:04:44.100302
149	9	8	Domainer	2	http://dummyimage.com/102x100.png/5fa2dd/ffffff	0	0	Cerebral infarction due to unspecified occlusion or stenosis of unspecified cerebellar artery	Corrosion of third degree of unspecified multiple fingers (nail), not including thumb, initial encounter	2023-06-03 15:04:44.156633	2023-06-03 15:04:44.156633
150	10	8	Sonair	2	http://dummyimage.com/177x100.png/dddddd/000000	0	0	Osteonecrosis in diseases classified elsewhere, hand	Poisoning by iron and its compounds, accidental (unintentional), initial encounter	2023-06-03 15:04:44.205872	2023-06-03 15:04:44.205872
151	11	8	Andalax	2	http://dummyimage.com/156x100.png/cc0000/ffffff	0	0	Salter-Harris Type II physeal fracture of lower end of right femur, subsequent encounter for fracture with delayed healing	Displaced comminuted fracture of shaft of radius, right arm, subsequent encounter for closed fracture with nonunion	2023-06-03 15:04:44.250263	2023-06-03 15:04:44.250263
152	12	8	Latlux	2	http://dummyimage.com/177x100.png/cc0000/ffffff	0	0	Other fracture of left foot, initial encounter for open fracture	Pre-existing secondary hypertension complicating pregnancy, second trimester	2023-06-03 15:04:44.29748	2023-06-03 15:04:44.29748
153	13	8	Zaam-Dox	2	http://dummyimage.com/120x100.png/ff4444/ffffff	0	0	Nondisplaced transverse fracture of shaft of unspecified radius, initial encounter for closed fracture	Osteolysis, unspecified forearm	2023-06-03 15:04:44.343915	2023-06-03 15:04:44.343915
154	14	8	Tin	2	http://dummyimage.com/206x100.png/cc0000/ffffff	0	0	Blood alcohol level of 80-99 mg/100 ml	Psychotic disorder with delusions due to known physiological condition	2023-06-03 15:04:44.390526	2023-06-03 15:04:44.390526
155	15	8	Greenlam	2	http://dummyimage.com/185x100.png/ff4444/ffffff	0	0	Breakdown (mechanical) of other specified internal prosthetic devices, implants and grafts	Miotic pupillary cyst, left eye	2023-06-03 15:04:44.438824	2023-06-03 15:04:44.438824
156	16	8	Quo Lux	2	http://dummyimage.com/243x100.png/dddddd/000000	0	0	Other specified noninflammatory disorders of vulva and perineum	Sedative, hypnotic or anxiolytic use, unspecified with intoxication, unspecified	2023-06-03 15:04:44.488596	2023-06-03 15:04:44.488596
157	17	8	Bigtax	1	http://dummyimage.com/177x100.png/cc0000/ffffff	0	0	Other superficial bite of hip, left hip	Adverse effect of other hormone antagonists, subsequent encounter	2023-06-03 15:04:44.535519	2023-06-03 15:04:44.535519
158	18	8	Rank	3	http://dummyimage.com/171x100.png/ff4444/ffffff	0	0	Poisoning by mixed antiepileptics, undetermined, initial encounter	Cerebral infarction due to thrombosis of right posterior cerebral artery	2023-06-03 15:04:44.579945	2023-06-03 15:04:44.579945
159	19	8	Biodex	3	http://dummyimage.com/227x100.png/dddddd/000000	0	0	Subacute osteomyelitis, radius and ulna	Keratoconjunctivitis due to Acanthamoeba	2023-06-03 15:04:44.638437	2023-06-03 15:04:44.638437
160	20	8	Bigtax	1	http://dummyimage.com/173x100.png/5fa2dd/ffffff	0	0	Burn due to (nonpowered) inflatable craft on fire	Drug or chemical induced diabetes mellitus with proliferative diabetic retinopathy with combined traction retinal detachment and rhegmatogenous retinal detachment, right eye	2023-06-03 15:04:44.685175	2023-06-03 15:04:44.685175
161	1	9	Daltfresh	1	http://dummyimage.com/169x100.png/5fa2dd/ffffff	0	0	Other superficial bite of right ear, sequela	Displaced comminuted fracture of shaft of left femur, subsequent encounter for closed fracture with routine healing	2023-06-03 15:04:44.730525	2023-06-03 15:04:44.730525
162	2	9	Aerified	3	http://dummyimage.com/178x100.png/dddddd/000000	0	0	Injury of extensor muscle, fascia and tendon of other and unspecified finger at wrist and hand level	Cystic kidney disease, unspecified	2023-06-03 15:04:44.784803	2023-06-03 15:04:44.784803
163	3	9	Solarbreeze	3	http://dummyimage.com/142x100.png/cc0000/ffffff	0	0	Recurrent dislocation, unspecified wrist	Steroid responder, bilateral	2023-06-03 15:04:44.828384	2023-06-03 15:04:44.828384
164	4	9	Stringtough	1	http://dummyimage.com/204x100.png/cc0000/ffffff	0	0	Unspecified occupant of heavy transport vehicle injured in collision with car, pick-up truck or van in traffic accident, sequela	Displacement of implanted electronic neurostimulator of spinal cord electrode (lead), sequela	2023-06-03 15:04:44.874282	2023-06-03 15:04:44.874282
165	5	9	Alphazap	2	http://dummyimage.com/246x100.png/ff4444/ffffff	0	0	Fracture of unspecified phalanx of left little finger, sequela	Drug-induced chronic gout, left elbow, without tophus (tophi)	2023-06-03 15:04:44.926343	2023-06-03 15:04:44.926343
166	6	9	Flexidy	3	http://dummyimage.com/218x100.png/cc0000/ffffff	0	0	Familial chondrocalcinosis, ankle and foot	Puncture wound with foreign body of other part of head, initial encounter	2023-06-03 15:04:44.971928	2023-06-03 15:04:44.971928
167	7	9	Domainer	1	http://dummyimage.com/218x100.png/5fa2dd/ffffff	0	0	Unspecified injury of left kidney, initial encounter	Poisoning by cardiac-stimulant glycosides and drugs of similar action, intentional self-harm, subsequent encounter	2023-06-03 15:04:45.01667	2023-06-03 15:04:45.01667
168	8	9	Ventosanzap	3	http://dummyimage.com/217x100.png/dddddd/000000	0	0	Other calcification of muscle, right forearm	Unspecified blepharitis unspecified eye, unspecified eyelid	2023-06-03 15:04:45.062959	2023-06-03 15:04:45.062959
169	9	9	Bytecard	1	http://dummyimage.com/229x100.png/ff4444/ffffff	0	0	Glaucomatous optic atrophy, bilateral	Adverse effect of antitussives	2023-06-03 15:04:45.106914	2023-06-03 15:04:45.106914
170	10	9	Cookley	3	http://dummyimage.com/219x100.png/ff4444/ffffff	0	0	Other fracture of shaft of right humerus, sequela	Varicose veins of left lower extremity with both ulcer of heel and midfoot and inflammation	2023-06-03 15:04:45.148743	2023-06-03 15:04:45.148743
171	11	9	Tempsoft	3	http://dummyimage.com/230x100.png/cc0000/ffffff	0	0	Unspecified fracture of upper end of humerus	Type 1 diabetes mellitus with skin complications	2023-06-03 15:04:45.199931	2023-06-03 15:04:45.199931
172	12	9	Home Ing	3	http://dummyimage.com/171x100.png/5fa2dd/ffffff	0	0	Unspecified injury of lung, bilateral, sequela	Other specified sprain of right wrist, initial encounter	2023-06-03 15:04:45.253055	2023-06-03 15:04:45.253055
173	13	9	Wrapsafe	3	http://dummyimage.com/246x100.png/cc0000/ffffff	0	0	Leakage of insulin pump, subsequent encounter	Nondisplaced fracture of fourth metatarsal bone, left foot, initial encounter for open fracture	2023-06-03 15:04:45.368976	2023-06-03 15:04:45.368976
174	14	9	Job	3	http://dummyimage.com/211x100.png/cc0000/ffffff	0	0	Other calcification of muscle, right ankle and foot	Nondisplaced dome fracture of unspecified talus, subsequent encounter for fracture with delayed healing	2023-06-03 15:04:45.416054	2023-06-03 15:04:45.416054
175	15	9	Bamity	2	http://dummyimage.com/236x100.png/dddddd/000000	0	0	Rheumatoid lung disease with rheumatoid arthritis of right shoulder	Fracture of unspecified phalanx of right middle finger, initial encounter for open fracture	2023-06-03 15:04:45.465076	2023-06-03 15:04:45.465076
176	16	9	Keylex	1	http://dummyimage.com/180x100.png/ff4444/ffffff	0	0	Blister (nonthermal), unspecified ankle	Pressure ulcer of right hip	2023-06-03 15:04:45.50962	2023-06-03 15:04:45.50962
177	17	9	Fix San	3	http://dummyimage.com/188x100.png/dddddd/000000	0	0	Underdosing of mineralocorticoids and their antagonists, initial encounter	Obesity complicating pregnancy, childbirth, and the puerperium	2023-06-03 15:04:45.559261	2023-06-03 15:04:45.559261
178	18	9	Namfix	3	http://dummyimage.com/130x100.png/cc0000/ffffff	0	0	Partial traumatic amputation at left shoulder joint, initial encounter	Quadriplegia, C1-C4 incomplete	2023-06-03 15:04:45.602291	2023-06-03 15:04:45.602291
179	19	9	Flexidy	1	http://dummyimage.com/219x100.png/ff4444/ffffff	0	0	Terrorism involving fires, conflagration and hot substances, public safety official injured, sequela	Gastrointestinal mucormycosis	2023-06-03 15:04:45.651945	2023-06-03 15:04:45.651945
180	20	9	Pannier	3	http://dummyimage.com/168x100.png/5fa2dd/ffffff	0	0	Complete traumatic metacarpophalangeal amputation of right ring finger, sequela	Other specified injuries of thorax, sequela	2023-06-03 15:04:45.694321	2023-06-03 15:04:45.694321
181	1	10	Viva	1	http://dummyimage.com/157x100.png/ff4444/ffffff	0	0	Pathological fracture in neoplastic disease, left hand, subsequent encounter for fracture with nonunion	Underdosing of other parasympatholytics [anticholinergics and antimuscarinics] and spasmolytics, sequela	2023-06-03 15:04:45.738939	2023-06-03 15:04:45.738939
182	2	10	Cookley	3	http://dummyimage.com/186x100.png/ff4444/ffffff	0	0	Cellulitis of left lower limb	Struck by baseball bat, sequela	2023-06-03 15:04:45.782611	2023-06-03 15:04:45.782611
183	3	10	Treeflex	2	http://dummyimage.com/178x100.png/5fa2dd/ffffff	0	0	Maternal care for known or suspected placental insufficiency, first trimester, fetus 5	Partial loss of teeth due to trauma, class I	2023-06-03 15:04:45.83004	2023-06-03 15:04:45.83004
184	4	10	Quo Lux	1	http://dummyimage.com/219x100.png/5fa2dd/ffffff	0	0	Other injury of extensor or abductor muscles, fascia and tendons of left thumb at forearm level, initial encounter	Unspecified injury of extensor muscle, fascia and tendon of unspecified finger at wrist and hand level, sequela	2023-06-03 15:04:45.884459	2023-06-03 15:04:45.884459
185	5	10	Treeflex	3	http://dummyimage.com/127x100.png/dddddd/000000	0	0	Assault by other hot objects, sequela	Infection specific to the perinatal period, unspecified	2023-06-03 15:04:45.936362	2023-06-03 15:04:45.936362
186	6	10	Pannier	1	http://dummyimage.com/175x100.png/5fa2dd/ffffff	0	0	Displaced trimalleolar fracture of left lower leg, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with delayed healing	Malignant neoplasm of undescended testis	2023-06-03 15:04:45.983179	2023-06-03 15:04:45.983179
187	7	10	Rank	2	http://dummyimage.com/188x100.png/5fa2dd/ffffff	0	0	Displaced transverse fracture of shaft of unspecified femur, initial encounter for open fracture type IIIA, IIIB, or IIIC	Puncture wound without foreign body of unspecified wrist, initial encounter	2023-06-03 15:04:46.026066	2023-06-03 15:04:46.026066
188	8	10	Alphazap	1	http://dummyimage.com/198x100.png/5fa2dd/ffffff	0	0	Rupture of synovium, left wrist	Burn of first degree of upper back, initial encounter	2023-06-03 15:04:46.076057	2023-06-03 15:04:46.076057
189	9	10	Bitwolf	1	http://dummyimage.com/102x100.png/cc0000/ffffff	0	0	Presence of right artificial elbow joint	Unspecified dislocation of right shoulder joint	2023-06-03 15:04:46.12843	2023-06-03 15:04:46.12843
190	10	10	Tampflex	1	http://dummyimage.com/227x100.png/cc0000/ffffff	0	0	Disorder of external ear, unspecified	Unspecified open wound of unspecified elbow, subsequent encounter	2023-06-03 15:04:46.179451	2023-06-03 15:04:46.179451
191	11	10	Hatity	2	http://dummyimage.com/114x100.png/cc0000/ffffff	0	0	Other shellfish poisoning, accidental (unintentional), subsequent encounter	Cocaine abuse with cocaine-induced mood disorder	2023-06-03 15:04:46.228379	2023-06-03 15:04:46.228379
192	12	10	Stringtough	1	http://dummyimage.com/235x100.png/5fa2dd/ffffff	0	0	Bipolar disorder, current episode depressed, moderate	Corrosion of unspecified degree of unspecified upper arm	2023-06-03 15:04:46.294326	2023-06-03 15:04:46.294326
193	13	10	Bytecard	2	http://dummyimage.com/151x100.png/ff4444/ffffff	0	0	Dislocation of left acromioclavicular joint, greater than 200% displacement, sequela	Adverse effect of selective serotonin and norepinephrine reuptake inhibitors, sequela	2023-06-03 15:04:46.346957	2023-06-03 15:04:46.346957
194	14	10	Temp	1	http://dummyimage.com/164x100.png/cc0000/ffffff	0	0	Poisoning by other anti-common-cold drugs, assault, initial encounter	Bitten by cat, sequela	2023-06-03 15:04:46.413729	2023-06-03 15:04:46.413729
195	15	10	Home Ing	2	http://dummyimage.com/124x100.png/ff4444/ffffff	0	0	Other specified injuries left forearm, subsequent encounter	Unspecified fracture of shaft of left tibia, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with delayed healing	2023-06-03 15:04:46.456878	2023-06-03 15:04:46.456878
196	16	10	Hatity	3	http://dummyimage.com/143x100.png/cc0000/ffffff	0	0	Unspecified fracture of right acetabulum, initial encounter for open fracture	Stress fracture, left femur, subsequent encounter for fracture with delayed healing	2023-06-03 15:04:46.504767	2023-06-03 15:04:46.504767
197	17	10	Ventosanzap	3	http://dummyimage.com/110x100.png/dddddd/000000	0	0	Diffuse follicle center lymphoma, spleen	Fear of flying	2023-06-03 15:04:46.633804	2023-06-03 15:04:46.633804
198	18	10	Lotstring	1	http://dummyimage.com/240x100.png/dddddd/000000	0	0	Unspecified contusion of spleen, initial encounter	Lateral dislocation of unspecified ulnohumeral joint, sequela	2023-06-03 15:04:46.692208	2023-06-03 15:04:46.692208
199	19	10	Biodex	1	http://dummyimage.com/187x100.png/5fa2dd/ffffff	0	0	Burn of unspecified degree of elbow	Burn with resulting rupture and destruction of left eyeball, sequela	2023-06-03 15:04:46.742407	2023-06-03 15:04:46.742407
200	20	10	Hatity	3	http://dummyimage.com/179x100.png/dddddd/000000	0	0	Acquired absence of unspecified ankle	Toxic effect of dichloromethane, intentional self-harm, initial encounter	2023-06-03 15:04:46.815146	2023-06-03 15:04:46.815146
201	1	11	Quo Lux	3	http://dummyimage.com/222x100.png/cc0000/ffffff	0	0	Medial subluxation of left ulnohumeral joint, sequela	Civilian injured by military aircraft, initial encounter	2023-06-03 15:04:46.867858	2023-06-03 15:04:46.867858
202	2	11	Job	2	http://dummyimage.com/131x100.png/ff4444/ffffff	0	0	Nondisplaced articular fracture of head of left femur, subsequent encounter for open fracture type I or II with delayed healing	Displaced transverse fracture of shaft of left radius, subsequent encounter for open fracture type I or II with malunion	2023-06-03 15:04:46.923815	2023-06-03 15:04:46.923815
203	3	11	Tin	2	http://dummyimage.com/158x100.png/5fa2dd/ffffff	0	0	Mycetoma, unspecified	Unspecified occupant of three-wheeled motor vehicle injured in collision with two- or three-wheeled motor vehicle in traffic accident	2023-06-03 15:04:46.969288	2023-06-03 15:04:46.969288
204	4	11	Asoka	3	http://dummyimage.com/111x100.png/5fa2dd/ffffff	0	0	Torus fracture of upper end of right radius, subsequent encounter for fracture with nonunion	Other injury of extensor or abductor muscles, fascia and tendons of unspecified thumb at forearm level, initial encounter	2023-06-03 15:04:47.009552	2023-06-03 15:04:47.009552
205	5	11	Regrant	1	http://dummyimage.com/130x100.png/dddddd/000000	0	0	Other disorders involving the immune mechanism, not elsewhere classified	Barton's fracture of unspecified radius, sequela	2023-06-03 15:04:47.056316	2023-06-03 15:04:47.056316
206	6	11	Aerified	3	http://dummyimage.com/143x100.png/ff4444/ffffff	0	0	Nondisplaced articular fracture of head of right femur, sequela	Unstable burst fracture of first cervical vertebra	2023-06-03 15:04:47.107544	2023-06-03 15:04:47.107544
207	7	11	Stim	2	http://dummyimage.com/133x100.png/cc0000/ffffff	0	0	Displaced fracture (avulsion) of lateral epicondyle of right humerus, initial encounter for closed fracture	Displaced fracture of lower epiphysis (separation) of left femur, subsequent encounter for open fracture type I or II with malunion	2023-06-03 15:04:47.152384	2023-06-03 15:04:47.152384
208	8	11	Biodex	1	http://dummyimage.com/174x100.png/cc0000/ffffff	0	0	Nondisplaced fracture of lesser trochanter of unspecified femur, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with delayed healing	Traumatic rupture of left radial collateral ligament	2023-06-03 15:04:47.198209	2023-06-03 15:04:47.198209
209	9	11	Fintone	2	http://dummyimage.com/125x100.png/ff4444/ffffff	0	0	Burn of second degree of unspecified axilla, sequela	Posterior dislocation of unspecified hip, initial encounter	2023-06-03 15:04:47.244854	2023-06-03 15:04:47.244854
210	10	11	Stringtough	1	http://dummyimage.com/198x100.png/5fa2dd/ffffff	0	0	Corrosion of unspecified degree of single right finger (nail) except thumb, subsequent encounter	Other fracture of lower end of left ulna, subsequent encounter for closed fracture with nonunion	2023-06-03 15:04:47.30272	2023-06-03 15:04:47.30272
211	11	11	Lotlux	2	http://dummyimage.com/235x100.png/dddddd/000000	0	0	Dislocation of metacarpophalangeal joint of right ring finger, subsequent encounter	Other mechanical complication of unspecified cardiac device, sequela	2023-06-03 15:04:47.355895	2023-06-03 15:04:47.355895
212	12	11	Stronghold	2	http://dummyimage.com/205x100.png/dddddd/000000	0	0	Person boarding or alighting a car injured in collision with heavy transport vehicle or bus, subsequent encounter	Displaced fracture of right ulna styloid process, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	2023-06-03 15:04:47.398259	2023-06-03 15:04:47.398259
213	13	11	Domainer	2	http://dummyimage.com/231x100.png/cc0000/ffffff	0	0	Unspecified superficial injury of lip, subsequent encounter	Abnormal findings on antenatal screening of mother	2023-06-03 15:04:47.440492	2023-06-03 15:04:47.440492
214	14	11	Overhold	1	http://dummyimage.com/209x100.png/5fa2dd/ffffff	0	0	Bucket-handle tear of lateral meniscus, current injury, left knee	Nondisplaced Type II dens fracture, initial encounter for closed fracture	2023-06-03 15:04:47.487146	2023-06-03 15:04:47.487146
215	15	11	Holdlamis	3	http://dummyimage.com/111x100.png/dddddd/000000	0	0	Other physeal fracture of lower end of right femur, subsequent encounter for fracture with nonunion	Terrorism, secondary effects	2023-06-03 15:04:47.531965	2023-06-03 15:04:47.531965
216	16	11	Konklab	3	http://dummyimage.com/187x100.png/cc0000/ffffff	0	0	Juvenile osteochondrosis of metatarsus, right foot	Chronic gout due to renal impairment, left elbow	2023-06-03 15:04:47.579222	2023-06-03 15:04:47.579222
217	17	11	Span	2	http://dummyimage.com/137x100.png/cc0000/ffffff	0	0	Unspecified fracture of right foot, initial encounter for closed fracture	Underdosing of other antiprotozoal drugs	2023-06-03 15:04:47.630064	2023-06-03 15:04:47.630064
218	18	11	Y-find	3	http://dummyimage.com/192x100.png/cc0000/ffffff	0	0	Other injury of bladder, subsequent encounter	Other multiple births, all stillborn	2023-06-03 15:04:47.674235	2023-06-03 15:04:47.674235
219	19	11	Greenlam	3	http://dummyimage.com/197x100.png/ff4444/ffffff	0	0	Poisoning by barbiturates, accidental (unintentional), sequela	Crushing injury of unspecified thumb, subsequent encounter	2023-06-03 15:04:47.720829	2023-06-03 15:04:47.720829
220	20	11	Treeflex	3	http://dummyimage.com/186x100.png/ff4444/ffffff	0	0	Pedal cycle passenger injured in collision with unspecified motor vehicles in nontraffic accident, sequela	Pathological fracture, hip, unspecified, subsequent encounter for fracture with delayed healing	2023-06-03 15:04:47.7757	2023-06-03 15:04:47.7757
221	1	12	Subin	2	http://dummyimage.com/230x100.png/dddddd/000000	0	0	Poisoning by anthelminthics, undetermined, sequela	Postdysenteric arthropathy, left knee	2023-06-03 15:04:47.822252	2023-06-03 15:04:47.822252
222	2	12	Sub-Ex	3	http://dummyimage.com/164x100.png/dddddd/000000	0	0	Hit or struck by falling object due to accident to sailboat, sequela	Unspecified occupant of pick-up truck or van injured in collision with railway train or railway vehicle in traffic accident	2023-06-03 15:04:47.867235	2023-06-03 15:04:47.867235
223	3	12	Hatity	2	http://dummyimage.com/190x100.png/dddddd/000000	0	0	Underdosing of keratolytics, keratoplastics, and other hair treatment drugs and preparations, subsequent encounter	Other atherosclerosis of native arteries of extremities, right leg	2023-06-03 15:04:47.920389	2023-06-03 15:04:47.920389
224	4	12	Fix San	2	http://dummyimage.com/156x100.png/ff4444/ffffff	0	0	Bitten by cat, initial encounter	Fracture of one rib, left side, initial encounter for open fracture	2023-06-03 15:04:47.960725	2023-06-03 15:04:47.960725
225	5	12	Duobam	1	http://dummyimage.com/191x100.png/ff4444/ffffff	0	0	Type 1 diabetes mellitus with proliferative diabetic retinopathy with traction retinal detachment not involving the macula, left eye	Diffuse traumatic brain injury with loss of consciousness of any duration with death due to brain injury prior to regaining consciousness, subsequent encounter	2023-06-03 15:04:48.010523	2023-06-03 15:04:48.010523
226	6	12	Tampflex	3	http://dummyimage.com/149x100.png/5fa2dd/ffffff	0	0	Atrioventricular block, first degree	Localization-related (focal) (partial) symptomatic epilepsy and epileptic syndromes with complex partial seizures, not intractable, without status epilepticus	2023-06-03 15:04:48.071919	2023-06-03 15:04:48.071919
227	7	12	Quo Lux	1	http://dummyimage.com/160x100.png/cc0000/ffffff	0	0	Stiffness of right elbow, not elsewhere classified	Other specified personal risk factors, not elsewhere classified	2023-06-03 15:04:48.122205	2023-06-03 15:04:48.122205
228	8	12	Bitwolf	2	http://dummyimage.com/144x100.png/cc0000/ffffff	0	0	Intentional self-harm by smoke, fire and flames, subsequent encounter	Nondisplaced transverse fracture of shaft of right tibia, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with malunion	2023-06-03 15:04:48.174971	2023-06-03 15:04:48.174971
229	9	12	Stronghold	2	http://dummyimage.com/242x100.png/ff4444/ffffff	0	0	Laceration of unspecified muscle, fascia and tendon at shoulder and upper arm level, left arm, initial encounter	Poisoning by antihyperlipidemic and antiarteriosclerotic drugs, undetermined, subsequent encounter	2023-06-03 15:04:48.231238	2023-06-03 15:04:48.231238
230	10	12	Stim	1	http://dummyimage.com/117x100.png/5fa2dd/ffffff	0	0	Pedestrian on skateboard injured in collision with pedal cycle, unspecified whether traffic or nontraffic accident, initial encounter	Motorcycle driver injured in collision with two- or three-wheeled motor vehicle in nontraffic accident, subsequent encounter	2023-06-03 15:04:48.274693	2023-06-03 15:04:48.274693
231	11	12	Sonsing	2	http://dummyimage.com/139x100.png/ff4444/ffffff	0	0	Unspecified fracture of shaft of right radius, subsequent encounter for open fracture type I or II with delayed healing	Unspecified fracture of lower end of left ulna, initial encounter for open fracture type I or II	2023-06-03 15:04:48.325696	2023-06-03 15:04:48.325696
232	12	12	Span	2	http://dummyimage.com/241x100.png/cc0000/ffffff	0	0	Other foreign object in bronchus	Unspecified injury of thoracic aorta	2023-06-03 15:04:48.369031	2023-06-03 15:04:48.369031
233	13	12	Bamity	1	http://dummyimage.com/225x100.png/cc0000/ffffff	0	0	Displaced posterior arch fracture of first cervical vertebra, subsequent encounter for fracture with delayed healing	Mononeuropathy in diseases classified elsewhere	2023-06-03 15:04:48.414833	2023-06-03 15:04:48.414833
234	14	12	Tin	3	http://dummyimage.com/146x100.png/dddddd/000000	0	0	Displaced comminuted fracture of shaft of unspecified tibia, subsequent encounter for closed fracture with delayed healing	Posterior dislocation of right acromioclavicular joint, subsequent encounter	2023-06-03 15:04:48.455032	2023-06-03 15:04:48.455032
235	15	12	Wrapsafe	2	http://dummyimage.com/155x100.png/dddddd/000000	0	0	Displaced fracture of posterior process of left talus, initial encounter for open fracture	Retinopathy of prematurity, stage 4, unspecified eye	2023-06-03 15:04:48.511386	2023-06-03 15:04:48.511386
236	16	12	Flowdesk	3	http://dummyimage.com/240x100.png/dddddd/000000	0	0	Puncture wound with foreign body of larynx	Sprain of interphalangeal joint of left ring finger, sequela	2023-06-03 15:04:48.595243	2023-06-03 15:04:48.595243
237	17	12	Cookley	3	http://dummyimage.com/122x100.png/ff4444/ffffff	0	0	Chloasma of right upper eyelid and periocular area	Other specified fracture of left acetabulum, subsequent encounter for fracture with routine healing	2023-06-03 15:04:48.643086	2023-06-03 15:04:48.643086
238	18	12	Namfix	3	http://dummyimage.com/238x100.png/5fa2dd/ffffff	0	0	Adverse effect of other bacterial vaccines, initial encounter	Salter-Harris Type I physeal fracture of upper end of radius, left arm, initial encounter for closed fracture	2023-06-03 15:04:48.743001	2023-06-03 15:04:48.743001
239	19	12	Pannier	3	http://dummyimage.com/230x100.png/5fa2dd/ffffff	0	0	Sarcoidosis of other sites	Sexual abuse complicating pregnancy, childbirth and the puerperium	2023-06-03 15:04:48.792339	2023-06-03 15:04:48.792339
240	20	12	Zathin	1	http://dummyimage.com/187x100.png/cc0000/ffffff	0	0	Foreign body in other and multiple parts of external eye, left eye, subsequent encounter	Other superficial bite of right shoulder, subsequent encounter	2023-06-03 15:04:49.3102	2023-06-03 15:04:49.3102
241	1	13	Sonsing	3	http://dummyimage.com/127x100.png/dddddd/000000	0	0	Fall (on) (from) other stairs and steps, sequela	Skeletal fluorosis, upper arm	2023-06-03 15:04:49.366987	2023-06-03 15:04:49.366987
242	2	13	Zontrax	1	http://dummyimage.com/105x100.png/ff4444/ffffff	0	0	Pedal cycle passenger injured in collision with pedestrian or animal in nontraffic accident, sequela	Toxic effect of tetrachloroethylene, accidental (unintentional), initial encounter	2023-06-03 15:04:49.417011	2023-06-03 15:04:49.417011
243	3	13	Cardify	1	http://dummyimage.com/122x100.png/5fa2dd/ffffff	0	0	Explosion of bomb placed during war operations but exploding after cessation of hostilities, civilian	Open bite of right cheek and temporomandibular area, sequela	2023-06-03 15:04:49.466948	2023-06-03 15:04:49.466948
244	4	13	Pannier	2	http://dummyimage.com/160x100.png/cc0000/ffffff	0	0	Cataract (lens) fragments in eye following cataract surgery	Unspecified fracture of navicular [scaphoid] bone of left wrist, subsequent encounter for fracture with routine healing	2023-06-03 15:04:49.512979	2023-06-03 15:04:49.512979
245	5	13	Bigtax	1	http://dummyimage.com/240x100.png/ff4444/ffffff	0	0	Paraneoplastic pemphigus	Adolescent idiopathic scoliosis, thoracic region	2023-06-03 15:04:49.556646	2023-06-03 15:04:49.556646
246	6	13	Y-Solowarm	2	http://dummyimage.com/246x100.png/ff4444/ffffff	0	0	Incomplete lesion of unspecified level of lumbar spinal cord	Sicca syndrome with other organ involvement	2023-06-03 15:04:49.603281	2023-06-03 15:04:49.603281
247	7	13	Alphazap	1	http://dummyimage.com/130x100.png/dddddd/000000	0	0	Other specified injury of muscle, fascia and tendon of the posterior muscle group at thigh level, right thigh, subsequent encounter	Person boarding or alighting a motorcycle injured in collision with other nonmotor vehicle, subsequent encounter	2023-06-03 15:04:49.65063	2023-06-03 15:04:49.65063
248	8	13	Greenlam	2	http://dummyimage.com/156x100.png/cc0000/ffffff	0	0	Nondisplaced fracture of triquetrum [cuneiform] bone, unspecified wrist, subsequent encounter for fracture with malunion	Other osteonecrosis, unspecified bone	2023-06-03 15:04:49.723049	2023-06-03 15:04:49.723049
249	9	13	Ventosanzap	3	http://dummyimage.com/195x100.png/cc0000/ffffff	0	0	Displaced fracture of medial condyle of unspecified femur, subsequent encounter for closed fracture with routine healing	Nondisplaced fracture of third metatarsal bone, unspecified foot, sequela	2023-06-03 15:04:49.772178	2023-06-03 15:04:49.772178
250	10	13	Biodex	2	http://dummyimage.com/167x100.png/ff4444/ffffff	0	0	Parachutist injured on landing	Nondisplaced transverse fracture of shaft of right tibia, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with delayed healing	2023-06-03 15:04:49.826564	2023-06-03 15:04:49.826564
251	11	13	Duobam	2	http://dummyimage.com/111x100.png/dddddd/000000	0	0	Displaced longitudinal fracture of right patella, initial encounter for closed fracture	Displaced fracture of middle third of navicular [scaphoid] bone of left wrist, subsequent encounter for fracture with routine healing	2023-06-03 15:04:49.880359	2023-06-03 15:04:49.880359
252	12	13	Quo Lux	3	http://dummyimage.com/126x100.png/cc0000/ffffff	0	0	Contusion of unspecified part of pancreas, subsequent encounter	Burn of first degree of head, face, and neck, unspecified site, initial encounter	2023-06-03 15:04:49.938677	2023-06-03 15:04:49.938677
253	13	13	Aerified	2	http://dummyimage.com/215x100.png/5fa2dd/ffffff	0	0	Underdosing of other psychodysleptics, sequela	Other complications specific to multiple gestation, second trimester, fetus 5	2023-06-03 15:04:50.001725	2023-06-03 15:04:50.001725
254	14	13	Tres-Zap	2	http://dummyimage.com/201x100.png/ff4444/ffffff	0	0	Puckering of macula	Acculturation difficulty	2023-06-03 15:04:50.048144	2023-06-03 15:04:50.048144
255	15	13	Andalax	1	http://dummyimage.com/123x100.png/5fa2dd/ffffff	0	0	Ocular laceration and rupture with prolapse or loss of intraocular tissue	Laceration of unspecified renal vein, sequela	2023-06-03 15:04:50.110683	2023-06-03 15:04:50.110683
256	16	13	Greenlam	2	http://dummyimage.com/146x100.png/5fa2dd/ffffff	0	0	Other fracture of shaft of right tibia, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with malunion	Corrosion of unspecified degree of multiple left fingers (nail), including thumb, subsequent encounter	2023-06-03 15:04:50.159221	2023-06-03 15:04:50.159221
257	17	13	Zathin	3	http://dummyimage.com/173x100.png/ff4444/ffffff	0	0	Strain of flexor muscle, fascia and tendon of right ring finger at wrist and hand level	Diabetes mellitus due to underlying condition with diabetic cataract	2023-06-03 15:04:50.210058	2023-06-03 15:04:50.210058
258	18	13	Stim	3	http://dummyimage.com/134x100.png/cc0000/ffffff	0	0	Supervision of other high risk pregnancies, first trimester	Other dislocation of right ulnohumeral joint, initial encounter	2023-06-03 15:04:50.255883	2023-06-03 15:04:50.255883
259	19	13	Trippledex	3	http://dummyimage.com/240x100.png/dddddd/000000	0	0	Other osteoporosis with current pathological fracture, unspecified lower leg	Drug or chemical induced diabetes mellitus with proliferative diabetic retinopathy with traction retinal detachment involving the macula, unspecified eye	2023-06-03 15:04:50.312066	2023-06-03 15:04:50.312066
260	20	13	Tin	3	http://dummyimage.com/159x100.png/cc0000/ffffff	0	0	Assault by blunt object	Pathological fracture in neoplastic disease, right foot	2023-06-03 15:04:50.357212	2023-06-03 15:04:50.357212
261	1	14	Alphazap	2	http://dummyimage.com/134x100.png/5fa2dd/ffffff	0	0	Nondisplaced fracture of right tibial spine, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with nonunion	Burn of second degree of unspecified forearm, subsequent encounter	2023-06-03 15:04:50.410314	2023-06-03 15:04:50.410314
262	2	14	Ronstring	2	http://dummyimage.com/187x100.png/ff4444/ffffff	0	0	Salter-Harris Type II physeal fracture of upper end of humerus, left arm, sequela	Nondisplaced unspecified fracture of unspecified lesser toe(s), subsequent encounter for fracture with malunion	2023-06-03 15:04:50.495081	2023-06-03 15:04:50.495081
264	4	14	Fixflex	1	http://dummyimage.com/187x100.png/ff4444/ffffff	0	0	Other contact with nonvenomous lizards, sequela	Car passenger injured in collision with two- or three-wheeled motor vehicle in traffic accident, initial encounter	2023-06-03 15:04:50.604781	2023-06-03 15:04:50.604781
265	5	14	Namfix	3	http://dummyimage.com/130x100.png/cc0000/ffffff	0	0	Other injuries of lung, unspecified, sequela	Failed attempted termination of pregnancy with other and unspecified complications	2023-06-03 15:04:50.681645	2023-06-03 15:04:50.681645
266	6	14	Solarbreeze	2	http://dummyimage.com/229x100.png/cc0000/ffffff	0	0	Struck by dolphin	Malignant neoplasm of lymphoid, hematopoietic and related tissue, unspecified	2023-06-03 15:04:50.73646	2023-06-03 15:04:50.73646
267	7	14	Opela	3	http://dummyimage.com/184x100.png/5fa2dd/ffffff	0	0	Skeletal fluorosis, forearm	Bank as the place of occurrence of the external cause	2023-06-03 15:04:50.834523	2023-06-03 15:04:50.834523
268	8	14	Aerified	2	http://dummyimage.com/226x100.png/dddddd/000000	0	0	Nondisplaced subtrochanteric fracture of unspecified femur, subsequent encounter for closed fracture with nonunion	Constant exophthalmos	2023-06-03 15:04:50.939005	2023-06-03 15:04:50.939005
269	9	14	Zaam-Dox	1	http://dummyimage.com/131x100.png/dddddd/000000	0	0	Other injury of intrinsic muscle, fascia and tendon of left little finger at wrist and hand level, sequela	Other misshapen ear	2023-06-03 15:04:51.038111	2023-06-03 15:04:51.038111
270	10	14	Bitchip	1	http://dummyimage.com/218x100.png/5fa2dd/ffffff	0	0	Nondisplaced fracture of distal phalanx of right index finger, subsequent encounter for fracture with delayed healing	Machinery accident on board fishing boat, initial encounter	2023-06-03 15:04:51.137605	2023-06-03 15:04:51.137605
271	11	14	Greenlam	2	http://dummyimage.com/188x100.png/cc0000/ffffff	0	0	Corrosion of third degree of unspecified lower leg, subsequent encounter	Adverse effect of other antacids and anti-gastric-secretion drugs, sequela	2023-06-03 15:04:51.235062	2023-06-03 15:04:51.235062
272	12	14	Viva	2	http://dummyimage.com/146x100.png/dddddd/000000	0	0	Rheumatoid arthritis of right wrist with involvement of other organs and systems	Laceration with foreign body of left little finger with damage to nail	2023-06-03 15:04:51.285227	2023-06-03 15:04:51.285227
273	13	14	Zathin	2	http://dummyimage.com/121x100.png/dddddd/000000	0	0	Eyelid retraction right upper eyelid	Laceration with foreign body of left great toe with damage to nail, sequela	2023-06-03 15:04:51.334221	2023-06-03 15:04:51.334221
274	14	14	It	2	http://dummyimage.com/159x100.png/ff4444/ffffff	0	0	Unspecified choroidal hemorrhage, left eye	Lymphoid leukemia, unspecified, in relapse	2023-06-03 15:04:51.383324	2023-06-03 15:04:51.383324
275	15	14	Voyatouch	2	http://dummyimage.com/113x100.png/ff4444/ffffff	0	0	Prolonged exposure in deep freeze unit or refrigerator, subsequent encounter	Nondisplaced fracture of fourth metatarsal bone, unspecified foot, subsequent encounter for fracture with routine healing	2023-06-03 15:04:51.53433	2023-06-03 15:04:51.53433
276	16	14	Tin	1	http://dummyimage.com/126x100.png/5fa2dd/ffffff	0	0	Maternal care for compound presentation, fetus 5	Laceration of axillary or brachial vein, right side, initial encounter	2023-06-03 15:04:51.634981	2023-06-03 15:04:51.634981
277	17	14	Voltsillam	1	http://dummyimage.com/224x100.png/dddddd/000000	0	0	Unspecified inflammatory spondylopathy, occipito-atlanto-axial region	Burn of second degree of unspecified site of right lower limb, except ankle and foot, subsequent encounter	2023-06-03 15:04:51.736081	2023-06-03 15:04:51.736081
278	18	14	Veribet	2	http://dummyimage.com/171x100.png/dddddd/000000	0	0	Supervision of high risk pregnancy due to social problems, first trimester	Nondisplaced fracture of neck of scapula, unspecified shoulder	2023-06-03 15:04:51.835317	2023-06-03 15:04:51.835317
279	19	14	Ronstring	2	http://dummyimage.com/110x100.png/5fa2dd/ffffff	0	0	Drowning and submersion in natural water, undetermined intent	Paralytic calcification and ossification of muscle, right hand	2023-06-03 15:04:51.876832	2023-06-03 15:04:51.876832
280	20	14	Opela	1	http://dummyimage.com/209x100.png/ff4444/ffffff	0	0	Spasm of accommodation, unspecified eye	Nondisplaced segmental fracture of shaft of unspecified fibula, sequela	2023-06-03 15:04:51.927142	2023-06-03 15:04:51.927142
281	1	15	Daltfresh	1	http://dummyimage.com/212x100.png/ff4444/ffffff	0	0	Unstable burst fracture of second thoracic vertebra, initial encounter for open fracture	Puncture wound without foreign body of anus, sequela	2023-06-03 15:04:51.991525	2023-06-03 15:04:51.991525
282	2	15	Redhold	3	http://dummyimage.com/129x100.png/ff4444/ffffff	0	0	Adverse effect of other opioids	Strain of flexor muscle, fascia and tendon of left ring finger at forearm level, initial encounter	2023-06-03 15:04:52.050372	2023-06-03 15:04:52.050372
283	3	15	Viva	2	http://dummyimage.com/171x100.png/cc0000/ffffff	0	0	Absolute glaucoma	Puncture wound with foreign body of right wrist, subsequent encounter	2023-06-03 15:04:52.236456	2023-06-03 15:04:52.236456
284	4	15	Redhold	2	http://dummyimage.com/195x100.png/5fa2dd/ffffff	0	0	Encounter for administrative examination	Fistula of joint	2023-06-03 15:04:52.332628	2023-06-03 15:04:52.332628
285	5	15	Ronstring	1	http://dummyimage.com/123x100.png/dddddd/000000	0	0	Other foreign body or object entering through skin, initial encounter	Unspecified superficial injury of unspecified lower leg, initial encounter	2023-06-03 15:04:52.43497	2023-06-03 15:04:52.43497
286	6	15	Zathin	2	http://dummyimage.com/124x100.png/cc0000/ffffff	0	0	Unspecified fracture of unspecified thoracic vertebra, initial encounter for open fracture	Displaced fracture of head of right radius, sequela	2023-06-03 15:04:52.47707	2023-06-03 15:04:52.47707
287	7	15	Cookley	2	http://dummyimage.com/246x100.png/5fa2dd/ffffff	0	0	Other injury of muscle, fascia and tendon of triceps, right arm, subsequent encounter	Unstable burst fracture of third lumbar vertebra	2023-06-03 15:04:52.52193	2023-06-03 15:04:52.52193
288	8	15	Job	3	http://dummyimage.com/115x100.png/cc0000/ffffff	0	0	Paraneoplastic pemphigus	Adverse effect of predominantly beta-adrenoreceptor agonists, initial encounter	2023-06-03 15:04:52.634601	2023-06-03 15:04:52.634601
289	9	15	Sonair	1	http://dummyimage.com/142x100.png/5fa2dd/ffffff	0	0	Sprain of jaw, left side, initial encounter	Thoracic, thoracolumbar and lumbosacral intervertebral disc disorders with myelopathy	2023-06-03 15:04:52.734321	2023-06-03 15:04:52.734321
290	10	15	Transcof	1	http://dummyimage.com/183x100.png/cc0000/ffffff	0	0	Displaced comminuted fracture of shaft of left tibia, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with malunion	Fracture of unspecified part of right clavicle, subsequent encounter for fracture with delayed healing	2023-06-03 15:04:52.78771	2023-06-03 15:04:52.78771
291	11	15	Sonair	2	http://dummyimage.com/206x100.png/dddddd/000000	0	0	Nondisplaced fracture of right ulna styloid process, subsequent encounter for closed fracture with malunion	Displaced fracture of pisiform, right wrist	2023-06-03 15:04:52.886912	2023-06-03 15:04:52.886912
292	12	15	Overhold	2	http://dummyimage.com/222x100.png/cc0000/ffffff	0	0	Age-related osteoporosis with current pathological fracture, unspecified shoulder	Other fracture of head and neck of left femur, subsequent encounter for open fracture type I or II with delayed healing	2023-06-03 15:04:52.931247	2023-06-03 15:04:52.931247
293	13	15	Cookley	3	http://dummyimage.com/105x100.png/cc0000/ffffff	0	0	Hemorrhagic choroidal detachment, left eye	Jumping or diving into natural body of water striking water surface causing other injury	2023-06-03 15:04:52.975419	2023-06-03 15:04:52.975419
294	14	15	Rank	2	http://dummyimage.com/142x100.png/cc0000/ffffff	0	0	Stress fracture, unspecified humerus, subsequent encounter for fracture with malunion	Nondisplaced fracture of lateral condyle of right tibia, subsequent encounter for closed fracture with routine healing	2023-06-03 15:04:53.025894	2023-06-03 15:04:53.025894
295	15	15	Andalax	2	http://dummyimage.com/197x100.png/cc0000/ffffff	0	0	Displaced transverse fracture of shaft of right femur, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	Sprain of interphalangeal joint of left index finger, initial encounter	2023-06-03 15:04:53.187157	2023-06-03 15:04:53.187157
296	16	15	Vagram	2	http://dummyimage.com/187x100.png/5fa2dd/ffffff	0	0	Spontaneous rupture of flexor tendons, upper arm	Other specified disorders of Eustachian tube, right ear	2023-06-03 15:04:53.334319	2023-06-03 15:04:53.334319
297	17	15	Domainer	3	http://dummyimage.com/248x100.png/ff4444/ffffff	0	0	Puncture wound without foreign body of hand	Injury of other nerves at forearm level, right arm	2023-06-03 15:04:53.380648	2023-06-03 15:04:53.380648
298	18	15	Tin	3	http://dummyimage.com/182x100.png/dddddd/000000	0	0	Toxic effect of trichloroethylene, accidental (unintentional), initial encounter	Anterior subluxation of right ulnohumeral joint	2023-06-03 15:04:53.483266	2023-06-03 15:04:53.483266
299	19	15	Subin	2	http://dummyimage.com/185x100.png/cc0000/ffffff	0	0	Displaced transverse fracture of right patella	Puncture wound with foreign body of left lesser toe(s) with damage to nail, initial encounter	2023-06-03 15:04:53.538957	2023-06-03 15:04:53.538957
300	20	15	Flexidy	1	http://dummyimage.com/104x100.png/ff4444/ffffff	0	0	Other specified disorders of Eustachian tube	Lead-induced chronic gout, right shoulder, without tophus (tophi)	2023-06-03 15:04:53.581196	2023-06-03 15:04:53.581196
\.


--
-- Data for Name: like; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public."like" (user_id, comment_id, created_at) FROM stdin;
\.


--
-- Data for Name: likes; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.likes (user_id, comment_id, created_at) FROM stdin;
\.


--
-- Data for Name: note; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.note (note_id, student_id, lesson_id, note, created_at, updated_at) FROM stdin;
1	2	1	Nicotine dependence, chewing tobacco, with withdrawal	2023-06-03 15:04:55.738751	2023-06-03 15:04:55.738751
2	2	21	Causalgia of unspecified lower limb	2023-06-03 15:04:55.784339	2023-06-03 15:04:55.784339
3	2	31	Contusion and laceration of left cerebrum without loss of consciousness	2023-06-03 15:04:55.827285	2023-06-03 15:04:55.827285
4	2	41	Other reduction defects of left lower limb	2023-06-03 15:04:55.873653	2023-06-03 15:04:55.873653
5	2	51	Acute hematogenous osteomyelitis, right humerus	2023-06-03 15:04:55.924614	2023-06-03 15:04:55.924614
6	2	61	Displaced transverse fracture of shaft of right tibia, subsequent encounter for open fracture type I or II with delayed healing	2023-06-03 15:04:55.981618	2023-06-03 15:04:55.981618
7	2	111	Open bite of unspecified wrist, initial encounter	2023-06-03 15:04:56.039783	2023-06-03 15:04:56.039783
8	2	171	Fracture of unspecified carpal bone, left wrist	2023-06-03 15:04:56.095254	2023-06-03 15:04:56.095254
9	2	181	Strain of muscle, fascia and tendon of long head of biceps, left arm	2023-06-03 15:04:56.139131	2023-06-03 15:04:56.139131
10	2	191	Major laceration of tail of pancreas, initial encounter	2023-06-03 15:04:56.185764	2023-06-03 15:04:56.185764
11	2	261	Acute lymphadenitis	2023-06-03 15:04:56.229279	2023-06-03 15:04:56.229279
12	2	271	Displaced fracture of greater trochanter of left femur, initial encounter for open fracture type IIIA, IIIB, or IIIC	2023-06-03 15:04:56.276619	2023-06-03 15:04:56.276619
13	2	281	Unspecified occupant of three-wheeled motor vehicle injured in collision with railway train or railway vehicle in nontraffic accident, initial encounter	2023-06-03 15:04:56.326206	2023-06-03 15:04:56.326206
14	2	291	Other physeal fracture of lower end of left tibia, subsequent encounter for fracture with malunion	2023-06-03 15:04:56.371822	2023-06-03 15:04:56.371822
15	2	51	Insect bite of other specified part of neck	2023-06-03 15:04:56.416204	2023-06-03 15:04:56.416204
16	2	61	Posterior dislocation of right radial head, initial encounter	2023-06-03 15:04:56.460376	2023-06-03 15:04:56.460376
17	2	111	Corrosion of third degree of right shoulder, sequela	2023-06-03 15:04:56.62274	2023-06-03 15:04:56.62274
18	2	171	Displaced fracture of posterior column [ilioischial] of left acetabulum	2023-06-03 15:04:56.683459	2023-06-03 15:04:56.683459
19	2	181	Intraoperative hemorrhage and hematoma of an endocrine system organ or structure complicating other procedure	2023-06-03 15:04:56.731958	2023-06-03 15:04:56.731958
20	2	191	Partial traumatic metacarpophalangeal amputation of right ring finger	2023-06-03 15:04:56.775819	2023-06-03 15:04:56.775819
21	2	261	Nondisplaced spiral fracture of shaft of right tibia	2023-06-03 15:04:56.827362	2023-06-03 15:04:56.827362
22	2	271	Left lower quadrant pain	2023-06-03 15:04:56.895188	2023-06-03 15:04:56.895188
23	2	281	Other malformation of placenta, second trimester	2023-06-03 15:04:56.944245	2023-06-03 15:04:56.944245
24	2	291	Nondisplaced osteochondral fracture of left patella, subsequent encounter for closed fracture with malunion	2023-06-03 15:04:56.991456	2023-06-03 15:04:56.991456
25	2	1	Toxic effect of carbon monoxide from other source, accidental (unintentional), initial encounter	2023-06-03 15:04:57.041592	2023-06-03 15:04:57.041592
26	2	21	Nondisplaced fracture of medial condyle of left femur, initial encounter for closed fracture	2023-06-03 15:04:57.08771	2023-06-03 15:04:57.08771
27	2	31	Other specified malignant neoplasm of skin of left upper limb, including shoulder	2023-06-03 15:04:57.151171	2023-06-03 15:04:57.151171
28	2	41	Acquired atrophy of ovary, unspecified side	2023-06-03 15:04:57.194791	2023-06-03 15:04:57.194791
29	2	51	Other contact with other marine mammals, subsequent encounter	2023-06-03 15:04:57.246582	2023-06-03 15:04:57.246582
30	2	61	Unspecified open wound of unspecified lesser toe(s) with damage to nail, subsequent encounter	2023-06-03 15:04:57.292313	2023-06-03 15:04:57.292313
31	2	111	Toxic effect of nitroderivatives and aminoderivatives of benzene and its homologues, undetermined, subsequent encounter	2023-06-03 15:04:57.336542	2023-06-03 15:04:57.336542
32	2	171	Infection and inflammatory reaction due to internal left knee prosthesis	2023-06-03 15:04:57.411191	2023-06-03 15:04:57.411191
33	2	181	Pathological fracture in other disease, left hand, sequela	2023-06-03 15:04:57.455843	2023-06-03 15:04:57.455843
34	2	191	Other rupture of muscle (nontraumatic), right ankle and foot	2023-06-03 15:04:57.501007	2023-06-03 15:04:57.501007
35	2	261	Effusion, right wrist	2023-06-03 15:04:57.54384	2023-06-03 15:04:57.54384
36	2	271	Dislocation of unspecified parts of unspecified shoulder girdle, subsequent encounter	2023-06-03 15:04:57.595066	2023-06-03 15:04:57.595066
37	2	281	Drowning and submersion due to fall off sailboat	2023-06-03 15:04:57.638946	2023-06-03 15:04:57.638946
38	2	291	Unspecified fracture of left forearm, subsequent encounter for open fracture type I or II with malunion	2023-06-03 15:04:57.683626	2023-06-03 15:04:57.683626
39	2	51	Laceration of other flexor muscle, fascia and tendon at forearm level, unspecified arm, initial encounter	2023-06-03 15:04:57.725682	2023-06-03 15:04:57.725682
40	2	61	Contusion of unspecified foot, initial encounter	2023-06-03 15:04:57.768294	2023-06-03 15:04:57.768294
41	3	31	Paraneoplastic neuromyopathy and neuropathy	2023-06-03 15:04:57.823316	2023-06-03 15:04:57.823316
42	3	41	Displaced oblique fracture of shaft of left radius, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	2023-06-03 15:04:57.870456	2023-06-03 15:04:57.870456
43	3	51	Unspecified transplanted organ and tissue rejection	2023-06-03 15:04:57.916314	2023-06-03 15:04:57.916314
44	3	61	Unspecified physeal fracture of phalanx of right toe, initial encounter for closed fracture	2023-06-03 15:04:57.958946	2023-06-03 15:04:57.958946
45	3	111	Retinopathy of prematurity, stage 0, left eye	2023-06-03 15:04:58.007071	2023-06-03 15:04:58.007071
46	3	171	Dislocation of interphalangeal joint of right lesser toe(s), initial encounter	2023-06-03 15:04:58.057931	2023-06-03 15:04:58.057931
47	3	181	Injury of trigeminal nerve, left side	2023-06-03 15:04:58.112329	2023-06-03 15:04:58.112329
48	3	191	Unspecified injury of left internal jugular vein, subsequent encounter	2023-06-03 15:04:58.159165	2023-06-03 15:04:58.159165
49	3	261	Salmonella pneumonia	2023-06-03 15:04:58.213028	2023-06-03 15:04:58.213028
50	3	271	Corrosion of third degree of multiple sites of lower limb, except ankle and foot	2023-06-03 15:04:58.259	2023-06-03 15:04:58.259
\.


--
-- Data for Name: part; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.part (part_id, exam_id, name, total_question, number_of_explanation, numeric_order, created_at, updated_at) FROM stdin;
1	1	Part 1	6	0	1	2023-06-03 23:24:23.313247	2023-06-03 23:24:32.875998
4	1	Part 4	30	0	4	2023-06-03 23:24:23.442731	2023-06-03 23:24:37.652513
7	1	Part 7	54	0	7	2023-06-03 23:24:23.572489	2023-06-03 23:24:43.588383
2	1	Part 2	25	0	2	2023-06-03 23:24:23.35678	2023-06-03 23:24:34.253352
5	1	Part 5	30	0	5	2023-06-03 23:24:23.48591	2023-06-03 23:24:39.245617
6	1	Part 6	16	0	6	2023-06-03 23:24:23.528294	2023-06-03 23:24:40.117397
3	1	Part 3	39	0	3	2023-06-03 23:24:23.399324	2023-06-03 23:24:36.107927
\.


--
-- Data for Name: part_option; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.part_option (exam_taking_id, part_id, created_at, updated_at) FROM stdin;
1	1	2023-06-03 23:25:44.055056	2023-06-03 23:25:44.055056
1	2	2023-06-03 23:25:44.098618	2023-06-03 23:25:44.098618
1	3	2023-06-03 23:25:44.142358	2023-06-03 23:25:44.142358
1	5	2023-06-03 23:25:44.185594	2023-06-03 23:25:44.185594
\.


--
-- Data for Name: question; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.question (question_id, set_question_id, hashtag_id, name, explain, order_qn, level, created_at, updated_at) FROM stdin;
1	1	1		<figure class="table"><table><tbody><tr><td><strong>Câu</strong></td><td><strong>ĐA</strong></td><td><strong>Lời thoại</strong></td><td><strong>Lí do loại/chọn</strong></td><td><strong>Dịch nghĩa</strong></td></tr><tr><td><strong>1</strong></td><td>A</td><td>He’s parking a truck</td><td>Sai verb</td><td><i>Anh ấy đang đậu xe tải</i></td></tr><tr><td>&nbsp;</td><td><strong>B</strong></td><td><strong>He’s lifting some furniture</strong></td><td>Đúng verb</td><td><strong>Anh ấy đang nâng đồ nội thất lên</strong></td></tr><tr><td>&nbsp;</td><td>C</td><td>He’s starting an engine</td><td>Sai verb</td><td><i>Anh ấy đang bắt đầu khởi động máy</i></td></tr><tr><td>&nbsp;</td><td>D</td><td>He’s driving a car</td><td>Sai verb</td><td><i>Anh ấy đang lái xe</i></td></tr></tbody></table></figure><p>&nbsp;</p><p>Từ vựng:</p><ol><li>parking(v): đậu, đỗ&nbsp;</li><li>lift(v): nâng</li><li>start an engine: khởi động máy</li></ol>	1	1	2023-06-03 23:24:32.434338	2023-06-03 23:24:32.434338
2	2	1		<figure class="table"><table><tbody><tr><td><strong>Câu</strong></td><td><strong>ĐA</strong></td><td><strong>Lời thoại</strong></td><td><strong>Lí do loại/chọn</strong></td><td><strong>Dịch nghĩa</strong></td></tr><tr><td><strong>2</strong></td><td>A</td><td>Some curtains have been closed</td><td>Sai verb (đúng phải là opened)</td><td><i>Rèn cửa bị đóng lại</i></td></tr><tr><td>&nbsp;</td><td>B</td><td>Some jackets have been laid on a chair</td><td>Không xuất hiện jackets trong tranh</td><td><i>Một vài cái áo khoác được đặt trên một cái</i> <i>ghế</i></td></tr><tr><td>&nbsp;</td><td><strong>C</strong></td><td><strong>Some people are gathered around a</strong> <strong>desk</strong></td><td>Đúng verb</td><td><strong>Một vài người đang tập hợp xunh quanh</strong> <strong>một cái bàn</strong></td></tr><tr><td>&nbsp;</td><td>D</td><td>Someone is turning on a lamp</td><td>Không ai chạm vào đèn</td><td><i>Một người nào đó đang bật đèn bàn</i></td></tr></tbody></table></figure>	2	1	2023-06-03 23:24:32.486717	2023-06-03 23:24:32.486717
3	3	1		<figure class="table"><table><tbody><tr><td><strong>Câu</strong></td><td><strong>ĐA</strong></td><td><strong>Lời thoại</strong></td><td><strong>Lí do loại/chọn</strong></td><td><strong>Dịch nghĩa</strong></td></tr><tr><td><strong>3</strong></td><td>A</td><td>One of the women is reaching into her bag</td><td>Sai verb (đúng phải là wearing/ carrying her bag)</td><td><i>Một người phụ nữ đang tiếp cận (lục tìm) bên trong túi xách của cô ấy.</i></td></tr><tr><td>&nbsp;</td><td><strong>B</strong></td><td><strong>The women are waiting in line</strong></td><td>Đúng verb</td><td><strong>Những người phụ nữ đang đợi thành một</strong> <strong>hàng</strong></td></tr><tr><td>&nbsp;</td><td>C</td><td>The man is leading a tour group</td><td>Sai verb</td><td><i>Người đàn ông đang dẫn dắt một nhóm</i> <i>người</i></td></tr><tr><td>&nbsp;</td><td>D</td><td>The man is opening a cash register</td><td>Sai verb</td><td><i>Người đàn ông đang mở máy tính tiền</i></td></tr></tbody></table></figure>	3	1	2023-06-03 23:24:32.6096	2023-06-03 23:24:32.6096
4	4	1		<figure class="table"><table><tbody><tr><td><strong>Câu</strong></td><td><strong>ĐA</strong></td><td><strong>Lời thoại</strong></td><td><strong>Lí do loại/chọn</strong></td><td><strong>Dịch nghĩa</strong></td></tr><tr><td>4</td><td><strong>A</strong></td><td><strong>The man is bending over a bicycle</strong></td><td>Đúng verb</td><td><strong>Người đàn ông đang cúi người xuống chiếc xe đạp</strong></td></tr><tr><td>&nbsp;</td><td>B</td><td>A wheel has been propped against a stack of bricks.</td><td>Sai verb</td><td><i>Một bánh xe được chống đỡ khỏi một chồng</i> <i>gạch</i></td></tr><tr><td>&nbsp;</td><td>C</td><td>The man is collecting some pieces of wood</td><td>Sai verb</td><td><i>Người đàn ông đang thu thập một vài miếng</i> <i>gỗ</i></td></tr><tr><td>&nbsp;</td><td>D</td><td>A handrail is being installed</td><td>Sai verb (không ai đụng vào lan can, nên lan can không thể nào đang được lắp đặt)</td><td><i>Một cái lan can cầu thang đang được lắp đặt</i></td></tr></tbody></table></figure>	4	1	2023-06-03 23:24:32.683528	2023-06-03 23:24:32.683528
5	5	2		<figure class="table"><table><tbody><tr><td><strong>Câu</strong></td><td><strong>ĐA</strong></td><td><strong>Lời thoại</strong></td><td><strong>Lí do loại/chọn</strong></td><td><strong>Dịch nghĩa</strong></td></tr><tr><td><strong>5</strong></td><td>A</td><td>An armchair has been placed under a window</td><td>Không xuất hiện window trong tranh</td><td><i>Một cái ghế được đặt ở phía dưới cửa sổ</i></td></tr><tr><td>&nbsp;</td><td>B</td><td>Some reading materials have fallen on the floor.</td><td>Không xuất hiện reading materials trong tranh</td><td><i>Một vài tài liệu đọc (sách) đã rơi xuống sàn</i></td></tr><tr><td>&nbsp;</td><td>C</td><td>Some flowers are being watered.</td><td>Loại being V3 với tranh không người.</td><td><i>Một vài bông hoa đang được tưới nước</i></td></tr><tr><td>&nbsp;</td><td><strong>D</strong></td><td><strong>Some picture frames are hanging on</strong> <strong>a wall</strong></td><td>&nbsp;</td><td><strong>Một vài khung ảnh đang treo trên tường.</strong></td></tr></tbody></table></figure>	5	1	2023-06-03 23:24:32.791179	2023-06-03 23:24:32.791179
6	6	2		<figure class="table"><table><tbody><tr><td><strong>Câu</strong></td><td><strong>ĐA</strong></td><td><strong>Lời thoại</strong></td><td><strong>Lí do loại/chọn</strong></td><td><strong>Dịch nghĩa</strong></td></tr><tr><td><strong>6</strong></td><td>A</td><td>She’s adjusting the height of an umbrella.</td><td>Sai Verb</td><td><i>Cô ấy đang điều chỉnh độ cao của chiếc ô</i></td></tr><tr><td>&nbsp;</td><td>B</td><td>She’s inspecting the tires on a vending cart.</td><td>Sai verb</td><td><i>Cô ấy đang kiểm tra lốp xe trên chiếc xe đẩy</i> <i>bán hàng</i></td></tr><tr><td>&nbsp;</td><td><strong>C</strong></td><td><strong>There’s a mobile food stand on a</strong> <strong>walkway.</strong></td><td>Đúng tình huống</td><td><strong>Có một quầy bán đồ ăn di động trên</strong> <strong>đường đi</strong></td></tr><tr><td>&nbsp;</td><td>D</td><td>There are some cooking utensils on the ground.</td><td>Không có gì trên mặt đất cả</td><td><i>Có một vài dụng cụ nấu ăn trên mặt đất</i></td></tr></tbody></table></figure>	6	1	2023-06-03 23:24:32.875998	2023-06-03 23:24:32.875998
7	7	3		<figure class="table"><table><tbody><tr><td><strong>Câu</strong></td><td><strong>ĐA</strong></td><td><strong>Lời thoại</strong></td><td><strong>Lí do loại/chọn</strong></td><td><strong>Dịch nghĩa</strong></td></tr><tr><td>7</td><td>&nbsp;</td><td><strong>Why </strong>was this afternoon’s meeting cancelled?</td><td>&nbsp;</td><td>Tại sao cuộc họp chiều nay bị hủy?</td></tr><tr><td>&nbsp;</td><td>A</td><td>whim 206 I think</td><td>Không hợp nghĩa</td><td>206 tôi nghĩ vậy</td></tr><tr><td>&nbsp;</td><td><strong>B</strong></td><td>Because the manager is out of the office.</td><td>Hợp nghĩa</td><td>Bởi vì quản lý không có ở văn phòng</td></tr><tr><td>&nbsp;</td><td>C</td><td>Let’s review the itinerary for our trip</td><td>Không hợp nghĩa</td><td>Hãy xem xét lịch trình cho chuyến đi của chúng ta.</td></tr></tbody></table></figure>	7	1	2023-06-03 23:24:33.034333	2023-06-03 23:24:33.034333
64	42	19	What does the woman like about a venue?		64	1	2023-06-03 23:24:35.842626	2023-06-03 23:24:35.842626
65	43	19	Why is the man surprised?		65	1	2023-06-03 23:24:35.885585	2023-06-03 23:24:35.885585
8	8	3		<figure class="table"><table><tbody><tr><td><strong>Câu</strong></td><td><strong>ĐA</strong></td><td><strong>Lời thoại</strong></td><td><strong>Lí do loại/chọn</strong></td><td><strong>Dịch nghĩa</strong></td></tr><tr><td>8</td><td>&nbsp;</td><td>You use the company fitness center, <strong>don’t you?</strong></td><td>&nbsp;</td><td>Bạn sử dụng phòng tập thể hình của công ty phải không?</td></tr><tr><td>&nbsp;</td><td><strong>A</strong></td><td>Yes. Every now and then</td><td>Hợp nghĩa</td><td>Vâng, thỉnh thoảng ạ.</td></tr><tr><td>&nbsp;</td><td>B</td><td>Please send her the text on the page.</td><td>Không hợp nghĩa</td><td>Làm ơn gửi cho cô ấy đoạn văn bản trên trang này.</td></tr><tr><td>&nbsp;</td><td>C</td><td>I think it fits you well.</td><td>Bẫy đồng âm fit &gt;&lt; fitness</td><td>Tôi nghĩ nó rất vừa vặn với bạn</td></tr></tbody></table></figure>	8	1	2023-06-03 23:24:33.134335	2023-06-03 23:24:33.134335
9	9	3		<figure class="table"><table><tbody><tr><td><strong>Câu</strong></td><td><strong>ĐA</strong></td><td><strong>Lời thoại</strong></td><td><strong>Lí do loại/chọn</strong></td><td><strong>Dịch nghĩa</strong></td></tr><tr><td>9</td><td>&nbsp;</td><td><strong>Do you have </strong>the images from the graphics department?</td><td>&nbsp;</td><td>Bạn có những bức ảnh từ phòng đồ họa không?</td></tr><tr><td>&nbsp;</td><td>A</td><td>Okay, that won’t be a problem.</td><td>Không hợp nghĩa</td><td>Được rồi, đó không phải là vấn đề</td></tr><tr><td>&nbsp;</td><td>B</td><td>A high definition camera.</td><td>Không hợp nghĩa</td><td>Một chiếc camera độ nét cao</td></tr><tr><td>&nbsp;</td><td><strong>C</strong></td><td>No, they’re not ready yet.</td><td>Hợp nghĩa</td><td>Không, chúng vẫn chưa sẵn sàng</td></tr></tbody></table></figure>	9	1	2023-06-03 23:24:33.234392	2023-06-03 23:24:33.234392
10	10	4		<figure class="table"><table><tbody><tr><td><strong>Câu</strong></td><td><strong>ĐA</strong></td><td><strong>Lời thoại</strong></td><td><strong>Lí do loại/chọn</strong></td><td><strong>Dịch nghĩa</strong></td></tr><tr><td>10</td><td>&nbsp;</td><td><strong>When </strong>are you moving to your new office?</td><td>&nbsp;</td><td>Khi nào bạn chuyển tới văn phòng mới?</td></tr><tr><td>&nbsp;</td><td>A</td><td>The office printer over there.</td><td>Bẫy đồng âm office</td><td>Máy in văn phòng ở đằng kia</td></tr><tr><td>&nbsp;</td><td>B</td><td>The water bill is high this month.</td><td>Không hợp nghĩa</td><td>Hóa đơn nước tháng này cao quá.</td></tr><tr><td>&nbsp;</td><td><strong>C</strong></td><td>The schedule is being revised.</td><td>Hợp nghĩa (câu trả lời gián tiếp)</td><td>Lịch trình đang được sửa đổi (nên chưa biết khi nào để trả lời).</td></tr></tbody></table></figure>	10	1	2023-06-03 23:24:33.281263	2023-06-03 23:24:33.281263
11	11	6			11	1	2023-06-03 23:24:33.324143	2023-06-03 23:24:33.324143
12	12	7			12	1	2023-06-03 23:24:33.367032	2023-06-03 23:24:33.367032
13	13	4			13	1	2023-06-03 23:24:33.409607	2023-06-03 23:24:33.409607
14	14	4			14	1	2023-06-03 23:24:33.452395	2023-06-03 23:24:33.452395
15	15	4			15	1	2023-06-03 23:24:33.521521	2023-06-03 23:24:33.521521
16	16	5			16	1	2023-06-03 23:24:33.595662	2023-06-03 23:24:33.595662
17	17	5			17	1	2023-06-03 23:24:33.638227	2023-06-03 23:24:33.638227
18	18	5			18	1	2023-06-03 23:24:33.683128	2023-06-03 23:24:33.683128
19	19	6			19	1	2023-06-03 23:24:33.72586	2023-06-03 23:24:33.72586
20	20	6			20	1	2023-06-03 23:24:33.768554	2023-06-03 23:24:33.768554
21	21	7			21	1	2023-06-03 23:24:33.811977	2023-06-03 23:24:33.811977
22	22	3			22	1	2023-06-03 23:24:33.855135	2023-06-03 23:24:33.855135
23	23	4			23	1	2023-06-03 23:24:33.898464	2023-06-03 23:24:33.898464
24	24	3			24	1	2023-06-03 23:24:33.942314	2023-06-03 23:24:33.942314
25	25	7			25	1	2023-06-03 23:24:33.985544	2023-06-03 23:24:33.985544
26	26	5			26	1	2023-06-03 23:24:34.028111	2023-06-03 23:24:34.028111
27	27	4			27	1	2023-06-03 23:24:34.072384	2023-06-03 23:24:34.072384
28	28	4			28	1	2023-06-03 23:24:34.123377	2023-06-03 23:24:34.123377
29	29	5			29	1	2023-06-03 23:24:34.16633	2023-06-03 23:24:34.16633
30	30	3			30	1	2023-06-03 23:24:34.209363	2023-06-03 23:24:34.209363
31	31	7			31	1	2023-06-03 23:24:34.253352	2023-06-03 23:24:34.253352
32	32	15	What is the woman preparing for?		32	1	2023-06-03 23:24:34.296065	2023-06-03 23:24:34.296065
33	32	26	Who most likely is the man?		33	1	2023-06-03 23:24:34.339073	2023-06-03 23:24:34.339073
34	32	16	What does the woman want to pick up on Friday morning?		34	1	2023-06-03 23:24:34.382751	2023-06-03 23:24:34.382751
35	33	16	What task is the man responsible for?		35	1	2023-06-03 23:24:34.428377	2023-06-03 23:24:34.428377
36	33	18	What does the woman want to do next year?		36	1	2023-06-03 23:24:34.471276	2023-06-03 23:24:34.471276
37	33	26	What does the man ask the woman to do?		37	1	2023-06-03 23:24:34.51416	2023-06-03 23:24:34.51416
38	34	24	What does the woman need a suit for?		38	1	2023-06-03 23:24:34.556855	2023-06-03 23:24:34.556855
39	34	15	What does the woman dislike about a suit on a display?		39	1	2023-06-03 23:24:34.605919	2023-06-03 23:24:34.605919
40	34	16	What does the man say that the price includes?		40	1	2023-06-03 23:24:34.661574	2023-06-03 23:24:34.661574
41	35	26	What kind of a business does the man most likely work for?		41	1	2023-06-03 23:24:34.704269	2023-06-03 23:24:34.704269
42	35	26	What does the woman say she is concerned about?		42	1	2023-06-03 23:24:34.748146	2023-06-03 23:24:34.748146
43	35	24	What does the woman agree to let the man do?		43	1	2023-06-03 23:24:34.79109	2023-06-03 23:24:34.79109
44	36	23	Who most likely is Axel Schmidt?		44	1	2023-06-03 23:24:34.845038	2023-06-03 23:24:34.845038
45	36	23	What renovation does the woman mention?		45	1	2023-06-03 23:24:34.889337	2023-06-03 23:24:34.889337
46	36	23	What does the woman encourage the man to do?		46	1	2023-06-03 23:24:34.932565	2023-06-03 23:24:34.932565
47	37	15	What is the woman preparing for?		47	1	2023-06-03 23:24:34.975439	2023-06-03 23:24:34.975439
48	37	15	Why is the woman surprised?		48	1	2023-06-03 23:24:35.019108	2023-06-03 23:24:35.019108
49	37	17	Why does the woman say, "The slides are available on our company intranet"?		49	1	2023-06-03 23:24:35.06296	2023-06-03 23:24:35.06296
50	38	17	According to the woman, what will happen at the end of November?		50	1	2023-06-03 23:24:35.106126	2023-06-03 23:24:35.106126
51	38	17	What does the man want to know?		51	1	2023-06-03 23:24:35.158082	2023-06-03 23:24:35.158082
52	38	18	What does the woman say the company will pay for?		52	1	2023-06-03 23:24:35.269726	2023-06-03 23:24:35.269726
53	39	18	What industry do the speakers work in?		53	1	2023-06-03 23:24:35.312271	2023-06-03 23:24:35.312271
54	39	18	What does the woman say a project will do for a city?		54	1	2023-06-03 23:24:35.359292	2023-06-03 23:24:35.359292
55	39	19	What does Gerhard say needs to be done?		55	1	2023-06-03 23:24:35.401972	2023-06-03 23:24:35.401972
56	40	19	What does the woman imply when she says, "I dont have much to do"?		56	1	2023-06-03 23:24:35.448512	2023-06-03 23:24:35.448512
57	40	19	What does the man notice about some medication?		57	1	2023-06-03 23:24:35.491588	2023-06-03 23:24:35.491588
58	40	19	What does the man suggest doing in the future?		58	1	2023-06-03 23:24:35.538951	2023-06-03 23:24:35.538951
59	41	20	Who most likely is the woman?		59	1	2023-06-03 23:24:35.583946	2023-06-03 23:24:35.583946
60	41	20	What kind of document are the speakers discussing?		60	1	2023-06-03 23:24:35.627773	2023-06-03 23:24:35.627773
61	41	21	Why must the document be revised by the end of the month?		61	1	2023-06-03 23:24:35.671184	2023-06-03 23:24:35.671184
62	42	21	Look at the graphic. How much did the man's company charge for its service?		62	1	2023-06-03 23:24:35.742999	2023-06-03 23:24:35.742999
63	42	20	Why does the man apologize?		63	1	2023-06-03 23:24:35.79719	2023-06-03 23:24:35.79719
66	43	18	Look at the graphic. In which section does the woman have seats?		66	1	2023-06-03 23:24:35.929571	2023-06-03 23:24:35.929571
67	43	18	What is the woman doing this weekend?		67	1	2023-06-03 23:24:35.972312	2023-06-03 23:24:35.972312
68	44	18	Who most likely is the man?		68	1	2023-06-03 23:24:36.015549	2023-06-03 23:24:36.015549
69	44	17	Look at the graphic. Which name needs to be changed?		69	1	2023-06-03 23:24:36.058551	2023-06-03 23:24:36.058551
70	44	17	What does the woman say she is going to do tomorrow?		70	1	2023-06-03 23:24:36.107927	2023-06-03 23:24:36.107927
71	45	30	What kind of business is the speaker most likely calling?		71	1	2023-06-03 23:24:36.165534	2023-06-03 23:24:36.165534
72	45	32	What does the speaker say about her appointment?		72	1	2023-06-03 23:24:36.238105	2023-06-03 23:24:36.238105
73	45	28	What is the speaker interested in learning more about?		73	1	2023-06-03 23:24:36.284	2023-06-03 23:24:36.284
74	46	27	What is being advertised?		74	1	2023-06-03 23:24:36.327473	2023-06-03 23:24:36.327473
75	46	27	What will participants receive?		75	1	2023-06-03 23:24:36.370001	2023-06-03 23:24:36.370001
76	46	36	What can the listeners do on a Web site?		76	1	2023-06-03 23:24:36.412468	2023-06-03 23:24:36.412468
77	47	35	Where does the announcement take place?		77	1	2023-06-03 23:24:36.457433	2023-06-03 23:24:36.457433
78	47	35	LWhy does the speaker apologize?		78	1	2023-06-03 23:24:36.504518	2023-06-03 23:24:36.504518
79	47	36	What does the speaker offer the listeners?		79	1	2023-06-03 23:24:36.549641	2023-06-03 23:24:36.549641
80	48	30	What event is taking place?		80	1	2023-06-03 23:24:36.593925	2023-06-03 23:24:36.593925
81	48	30	Why does the speaker say, "And over 300 people are here"?		81	1	2023-06-03 23:24:36.638943	2023-06-03 23:24:36.638943
82	48	31	What does the speaker ask the listeners to do?		82	1	2023-06-03 23:24:36.684294	2023-06-03 23:24:36.684294
83	49	31	What is the purpose of the plan?		83	1	2023-06-03 23:24:36.750089	2023-06-03 23:24:36.750089
84	49	32	Who does the speaker say will receive a discount?		84	1	2023-06-03 23:24:36.815182	2023-06-03 23:24:36.815182
85	49	32	What will happen after three months?		85	1	2023-06-03 23:24:36.890259	2023-06-03 23:24:36.890259
86	50	27	What event is the speaker discussing?		86	1	2023-06-03 23:24:36.943836	2023-06-03 23:24:36.943836
87	50	37	Why does the speaker say, "tickets are almost sold out"?		87	1	2023-06-03 23:24:36.992019	2023-06-03 23:24:36.992019
88	50	37	What will happen tomorrow morning?		88	1	2023-06-03 23:24:37.039433	2023-06-03 23:24:37.039433
89	51	35	What type of business does the speaker work for?		89	1	2023-06-03 23:24:37.088903	2023-06-03 23:24:37.088903
90	51	35	What does the speaker say is an advantage of the new material?		90	1	2023-06-03 23:24:37.146572	2023-06-03 23:24:37.146572
91	51	29	What will the listeners do next?		91	1	2023-06-03 23:24:37.249635	2023-06-03 23:24:37.249635
92	52	29	Which department does the speaker work in?		92	1	2023-06-03 23:24:37.301194	2023-06-03 23:24:37.301194
93	52	30	Why does the speaker say, "there is a need for a skilled software engineer"?		93	1	2023-06-03 23:24:37.346977	2023-06-03 23:24:37.346977
94	52	33	What does the speaker want to discuss with the listener?		94	1	2023-06-03 23:24:37.392512	2023-06-03 23:24:37.392512
95	53	34	Why are guests invited on the speakers radio show?		95	1	2023-06-03 23:24:37.436355	2023-06-03 23:24:37.436355
96	53	35	What can the listeners do on a Web site?		96	1	2023-06-03 23:24:37.4804	2023-06-03 23:24:37.4804
97	53	32	Look at the graphic. Which day is this episode being aired?		97	1	2023-06-03 23:24:37.522695	2023-06-03 23:24:37.522695
98	54	31	Look at the graphic. Where will the scarves and ties be displayed?		98	1	2023-06-03 23:24:37.565699	2023-06-03 23:24:37.565699
99	54	30	What should be displayed near the cash registers?		99	1	2023-06-03 23:24:37.609839	2023-06-03 23:24:37.609839
100	54	29	What should the listener expect to receive in an e-mail?		100	1	2023-06-03 23:24:37.652513	2023-06-03 23:24:37.652513
101	55	41	Mougey Fine Gifts is known for its large range of _____ goods.		101	1	2023-06-03 23:24:37.705524	2023-06-03 23:24:37.705524
102	56	41	Income levels are rising in the _____ and surrounding areas.		102	1	2023-06-03 23:24:37.785843	2023-06-03 23:24:37.785843
103	57	38	Since we had a recent rate change, expect _____ next electricity bill to be slightly lower.		103	1	2023-06-03 23:24:37.829334	2023-06-03 23:24:37.829334
104	58	39	Hotel guests have a lovely view of the ocean _____ the south-facing windows.		104	1	2023-06-03 23:24:37.872091	2023-06-03 23:24:37.872091
105	59	40	Mr. Kim would like _____ a meeting about the Jasper account as soon as possible.		105	1	2023-06-03 23:24:37.915164	2023-06-03 23:24:37.915164
106	60	38	The factory is _____ located near the train station.		106	1	2023-06-03 23:24:37.958967	2023-06-03 23:24:37.958967
107	61	38	Because of transportation _____ due to winter weather, some conference participants may arrive late.		107	1	2023-06-03 23:24:38.002747	2023-06-03 23:24:38.002747
108	62	38	Proper maintenance of your heating equipment ensures that small issues can be fixed _____ they become big ones.		108	1	2023-06-03 23:24:38.138995	2023-06-03 23:24:38.138995
109	63	39	The information on the Web site of Croyell Decorators is _____ organized.		109	1	2023-06-03 23:24:38.189458	2023-06-03 23:24:38.189458
110	64	41	The Copley Corporation is frequently _____ as a company that employs workers from all over the world.		110	1	2023-06-03 23:24:38.232714	2023-06-03 23:24:38.232714
111	65	41	Payments made _____ 4:00 P.M. will be processed on the following business day.		111	1	2023-06-03 23:24:38.275307	2023-06-03 23:24:38.275307
112	66	41	Greenfiddle Water Treatment hires engineers who have _____ mathematics skills.		112	1	2023-06-03 23:24:38.318663	2023-06-03 23:24:38.318663
113	67	38	After _____ the neighborhood, Mr. Park decided not to move his café to Thomasville.		113	1	2023-06-03 23:24:38.366617	2023-06-03 23:24:38.366617
114	68	39	The average precipitation in Campos _____ the past three years has been 7 centimeters.		114	1	2023-06-03 23:24:38.462037	2023-06-03 23:24:38.462037
115	69	41	Improving efficiency at Perwon Manufacturing will require a _____ revision of existing processes.		115	1	2023-06-03 23:24:38.509453	2023-06-03 23:24:38.509453
116	70	41	Conference attendees will share accommodations _____ they submit a special request for a single room.		116	1	2023-06-03 23:24:38.552115	2023-06-03 23:24:38.552115
117	71	40	To receive _____, please be sure the appropriate box is checked on the magazine order form.		117	1	2023-06-03 23:24:38.60097	2023-06-03 23:24:38.60097
118	72	39	Donations to the Natusi Wildlife Reserve rise when consumers feel _____ about the economy.		118	1	2023-06-03 23:24:38.647544	2023-06-03 23:24:38.647544
119	73	38	When _____ applied, Tilda`s Restorative Cream reduces the appearance of fine lines and wrinkles.		119	1	2023-06-03 23:24:38.690632	2023-06-03 23:24:38.690632
120	74	40	The marketing director confirmed that the new software program would be ready to _____ by November		120	1	2023-06-03 23:24:38.733886	2023-06-03 23:24:38.733886
121	75	41	Satinesse Seat Covers will refund your order _____ you are not completely satisfied.		121	1	2023-06-03 23:24:38.784452	2023-06-03 23:24:38.784452
122	76	38	In the last five years, production at the Harris facility has almost doubled in_____.		122	1	2023-06-03 23:24:38.828428	2023-06-03 23:24:38.828428
123	77	39	Ms. Tsai will _____ the installation of the new workstations with the vendor.		123	1	2023-06-03 23:24:38.883269	2023-06-03 23:24:38.883269
124	78	40	An upgrade in software would _____ increase the productivity of our administrative staff.		124	1	2023-06-03 23:24:38.974609	2023-06-03 23:24:38.974609
125	79	41	The Rustic Diner`s chef does allow patrons to make menu _____.		125	1	2023-06-03 23:24:39.017327	2023-06-03 23:24:39.017327
126	80	40	Ms. Rodriguez noted that it is important to _____ explicit policies regarding the use of company computers.		126	1	2023-06-03 23:24:39.062179	2023-06-03 23:24:39.062179
127	81	39	_____ Peura Insurance has located a larger office space, it will begin negotiating the rental agreement.		127	1	2023-06-03 23:24:39.108288	2023-06-03 23:24:39.108288
128	82	38	Mr. Tanaka`s team worked _____ for months to secure a lucrative government contract.		128	1	2023-06-03 23:24:39.155021	2023-06-03 23:24:39.155021
129	83	37	Though Sendak Agency`s travel insurance can be purchased over the phone, most of _____ plans are bought online.		129	1	2023-06-03 23:24:39.200622	2023-06-03 23:24:39.200622
130	84	38	Garstein Furniture specializes in functional products that are inexpensive _____ beautifully crafted.		130	1	2023-06-03 23:24:39.245617	2023-06-03 23:24:39.245617
131	85	42			131	1	2023-06-03 23:24:39.292515	2023-06-03 23:24:39.292515
132	85	46			132	1	2023-06-03 23:24:39.418754	2023-06-03 23:24:39.418754
133	85	44			133	1	2023-06-03 23:24:39.463173	2023-06-03 23:24:39.463173
134	85	43			134	1	2023-06-03 23:24:39.510553	2023-06-03 23:24:39.510553
135	86	44			135	1	2023-06-03 23:24:39.559062	2023-06-03 23:24:39.559062
136	86	46			136	1	2023-06-03 23:24:39.603579	2023-06-03 23:24:39.603579
137	86	44			137	1	2023-06-03 23:24:39.650253	2023-06-03 23:24:39.650253
138	86	42			138	1	2023-06-03 23:24:39.729672	2023-06-03 23:24:39.729672
139	87	43			139	1	2023-06-03 23:24:39.779017	2023-06-03 23:24:39.779017
140	87	46			140	1	2023-06-03 23:24:39.823243	2023-06-03 23:24:39.823243
141	87	43			141	1	2023-06-03 23:24:39.865626	2023-06-03 23:24:39.865626
142	87	44			142	1	2023-06-03 23:24:39.934309	2023-06-03 23:24:39.934309
143	88	44			143	1	2023-06-03 23:24:39.986019	2023-06-03 23:24:39.986019
144	88	44			144	1	2023-06-03 23:24:40.029387	2023-06-03 23:24:40.029387
145	88	45			145	1	2023-06-03 23:24:40.072092	2023-06-03 23:24:40.072092
146	88	45			146	1	2023-06-03 23:24:40.117397	2023-06-03 23:24:40.117397
147	89	49	What is the purpose of the announcement?		147	1	2023-06-03 23:24:40.203463	2023-06-03 23:24:40.203463
148	89	50	According to Mr. Clifford, what has the airline temporarily increased?		148	1	2023-06-03 23:24:40.254188	2023-06-03 23:24:40.254188
149	90	61	What are applicants for this position required to have?		149	1	2023-06-03 23:24:40.297715	2023-06-03 23:24:40.297715
150	90	61	What is true about the job?		150	1	2023-06-03 23:24:40.341144	2023-06-03 23:24:40.341144
151	91	60	What is true about the software testing?		151	1	2023-06-03 23:24:40.390164	2023-06-03 23:24:40.390164
152	91	47	What action was difficult for users to complete?		152	1	2023-06-03 23:24:40.433244	2023-06-03 23:24:40.433244
153	92	55	What is indicated about Ms. Atiyeh`s previous appearance at Mutamark?		153	1	2023-06-03 23:24:40.485477	2023-06-03 23:24:40.485477
154	92	54	How many people can the Koros Hall accommodate?		154	1	2023-06-03 23:24:40.530471	2023-06-03 23:24:40.530471
155	92	56	When will Ms. Atiyeh most likely appear at the Mutamark conference?		155	1	2023-06-03 23:24:40.599036	2023-06-03 23:24:40.599036
156	93	55	What kind of business most likely is Saenger, Inc.?		156	1	2023-06-03 23:24:40.646735	2023-06-03 23:24:40.646735
157	93	54	What is indicated about the monorail?		157	1	2023-06-03 23:24:40.737988	2023-06-03 23:24:40.737988
158	93	55	In which of the positions marked [1], [2], [3], and [4] does the following sentence best belong? "Along the way, the line will stop at nine stations."		158	1	2023-06-03 23:24:40.839171	2023-06-03 23:24:40.839171
159	94	61	At 3:01 P.M., what does Ms. McCall most likely mean when she writes, "No problem"?		159	1	2023-06-03 23:24:40.882682	2023-06-03 23:24:40.882682
160	94	60	What type of work does Ms. McCall most likely do?		160	1	2023-06-03 23:24:40.976644	2023-06-03 23:24:40.976644
161	95	47	What is suggested about the craft fair?		161	1	2023-06-03 23:24:41.019642	2023-06-03 23:24:41.019642
162	95	52	What is NOT mentioned as a requirement for selling at the craft fair?		162	1	2023-06-03 23:24:41.080593	2023-06-03 23:24:41.080593
163	95	53	What does Ms. Renaldo most likely sell?		163	1	2023-06-03 23:24:41.124067	2023-06-03 23:24:41.124067
164	95	54	In which of the positions marked [1], [2], [3], and [4] does the following sentence best belong? "Make sure they clearly represent the items you wish to offer for purchase at the event."		164	1	2023-06-03 23:24:41.193854	2023-06-03 23:24:41.193854
165	96	57	In what industry does Sleep Soundly Solutions operate?		165	1	2023-06-03 23:24:41.246975	2023-06-03 23:24:41.246975
166	96	58	What new product is being offered by Sleep Soundly Solutions?		166	1	2023-06-03 23:24:41.338946	2023-06-03 23:24:41.338946
167	96	50	The word "meet" in paragraph 3, line 3, is closest in meaning to		167	1	2023-06-03 23:24:41.38254	2023-06-03 23:24:41.38254
168	97	59	What is one purpose of the letter?		168	1	2023-06-03 23:24:41.42494	2023-06-03 23:24:41.42494
169	97	59	The word "established" in paragraph 1, line 3, is closest in meaning to		169	1	2023-06-03 23:24:41.476069	2023-06-03 23:24:41.476069
170	97	49	What is suggested about Dr. Geerlings?		170	1	2023-06-03 23:24:41.518775	2023-06-03 23:24:41.518775
171	97	49	What is NOT indicated about JATA in the letter?		171	1	2023-06-03 23:24:41.57598	2023-06-03 23:24:41.57598
172	98	53	For what type of company do the writers work?		172	1	2023-06-03 23:24:41.625455	2023-06-03 23:24:41.625455
173	98	54	At 8:59 A.M., what does Ms. Randolph most likely mean when she writes, "Not at all"?		173	1	2023-06-03 23:24:41.735267	2023-06-03 23:24:41.735267
174	98	58	What is indicated about Mr. Erickson?		174	1	2023-06-03 23:24:41.778825	2023-06-03 23:24:41.778825
175	98	58	According to the discussion, what is important to Mr. Peters about a new hire?		175	1	2023-06-03 23:24:41.875795	2023-06-03 23:24:41.875795
176	99	49	What is NOT recommended in the article?		176	1	2023-06-03 23:24:41.918579	2023-06-03 23:24:41.918579
177	99	49	Why are blinds mentioned?		177	1	2023-06-03 23:24:41.980755	2023-06-03 23:24:41.980755
178	99	50	What is indicated about the magazine?		178	1	2023-06-03 23:24:42.024282	2023-06-03 23:24:42.024282
179	99	51	What is suggested about Ms. Testa?		179	1	2023-06-03 23:24:42.134333	2023-06-03 23:24:42.134333
180	99	47	What is suggested about Moveable, Inc.`s products?		180	1	2023-06-03 23:24:42.18465	2023-06-03 23:24:42.18465
181	100	49	How does Tour 1 differ from all the other tours?		181	1	2023-06-03 23:24:42.230614	2023-06-03 23:24:42.230614
182	100	61	What is included in the cost of the tours?		182	1	2023-06-03 23:24:42.284543	2023-06-03 23:24:42.284543
183	100	52	What tour did Ms. Bouton most likely take?		183	1	2023-06-03 23:24:42.327337	2023-06-03 23:24:42.327337
184	100	53	What does the review suggest about Ms. Bouton?		184	1	2023-06-03 23:24:42.434328	2023-06-03 23:24:42.434328
185	100	54	Why was Ms. Bouton disappointed with the tour?		185	1	2023-06-03 23:24:42.53433	2023-06-03 23:24:42.53433
186	101	55	What most likely is the topic of the seminar on June 11 ?		186	1	2023-06-03 23:24:42.634832	2023-06-03 23:24:42.634832
187	101	55	What iS suggested about Mr. Morgan?		187	1	2023-06-03 23:24:42.734456	2023-06-03 23:24:42.734456
188	101	56	What is the purpose of the notice?		188	1	2023-06-03 23:24:42.794875	2023-06-03 23:24:42.794875
189	101	54	According to the second e-mail, what does Mr. Morgan suggest changing?		189	1	2023-06-03 23:24:42.841061	2023-06-03 23:24:42.841061
190	101	53	How much did Mr. Morgan spend on the book he showed to Ms. Tsu?		190	1	2023-06-03 23:24:42.888006	2023-06-03 23:24:42.888006
191	102	54	What is the purpose of the article?		191	1	2023-06-03 23:24:43.034343	2023-06-03 23:24:43.034343
192	102	56	What positive aspect of the Anton Building does Ms. Yadav mention?		192	1	2023-06-03 23:24:43.134328	2023-06-03 23:24:43.134328
193	102	55	What is suggested about JPD in Ms. Bautista`s e-mail?		193	1	2023-06-03 23:24:43.234325	2023-06-03 23:24:43.234325
194	102	47	What information about the building does Ms. Bautista request from Mr. Rowell?		194	1	2023-06-03 23:24:43.284343	2023-06-03 23:24:43.284343
195	102	59	What space would Lenoiva most likely choose to rent?		195	1	2023-06-03 23:24:43.32922	2023-06-03 23:24:43.32922
196	103	59	What does Ms. Jefferson mention in the first e-mail?		196	1	2023-06-03 23:24:43.380125	2023-06-03 23:24:43.380125
197	103	60	What rental option best meets Ms. Jefferson`s needs?		197	1	2023-06-03 23:24:43.442264	2023-06-03 23:24:43.442264
198	103	57	What is the hourly rate of DGC`s newest rental option?		198	1	2023-06-03 23:24:43.501852	2023-06-03 23:24:43.501852
199	103	57	What is indicated about DGC in the price list?		199	1	2023-06-03 23:24:43.545796	2023-06-03 23:24:43.545796
200	103	57	According to the price list, what is true about all boats?		200	1	2023-06-03 23:24:43.588383	2023-06-03 23:24:43.588383
\.


--
-- Data for Name: rank; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.rank (rank_id, rank_name, point_to_unlock, created_at, updated_at) FROM stdin;
1	Luyện Khí	1000	2023-06-03 15:04:10.301208	2023-06-03 15:04:10.301208
2	Trúc Cơ	2000	2023-06-03 15:04:10.344745	2023-06-03 15:04:10.344745
3	Kim Đan	3000	2023-06-03 15:04:10.39432	2023-06-03 15:04:10.39432
4	Nguyên Anh	4000	2023-06-03 15:04:10.438074	2023-06-03 15:04:10.438074
5	Hoá Thần	5000	2023-06-03 15:04:10.482972	2023-06-03 15:04:10.482972
6	Luyện Hư	6000	2023-06-03 15:04:10.531425	2023-06-03 15:04:10.531425
7	Hợp Thể	7000	2023-06-03 15:04:10.582694	2023-06-03 15:04:10.582694
8	Đại Thừa	8000	2023-06-03 15:04:10.645686	2023-06-03 15:04:10.645686
9	Độ Kiếp	9000	2023-06-03 15:04:10.699142	2023-06-03 15:04:10.699142
\.


--
-- Data for Name: rating; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.rating (student_id, course_id, rate, created_at, updated_at) FROM stdin;
1	1	3	2023-06-03 15:04:58.56547	2023-06-03 15:04:58.56547
1	2	5	2023-06-03 15:04:58.637058	2023-06-03 15:04:58.637058
1	3	4	2023-06-03 15:04:58.701629	2023-06-03 15:04:58.701629
1	4	3	2023-06-03 15:04:58.774324	2023-06-03 15:04:58.774324
1	5	4	2023-06-03 15:04:58.829437	2023-06-03 15:04:58.829437
1	6	1	2023-06-03 15:04:58.924922	2023-06-03 15:04:58.924922
1	7	4	2023-06-03 15:04:58.994869	2023-06-03 15:04:58.994869
1	8	5	2023-06-03 15:04:59.059231	2023-06-03 15:04:59.059231
1	9	4	2023-06-03 15:04:59.105352	2023-06-03 15:04:59.105352
1	10	2	2023-06-03 15:04:59.151168	2023-06-03 15:04:59.151168
2	1	3	2023-06-03 15:04:59.201217	2023-06-03 15:04:59.201217
2	2	3	2023-06-03 15:04:59.24556	2023-06-03 15:04:59.24556
2	3	2	2023-06-03 15:04:59.305879	2023-06-03 15:04:59.305879
2	4	1	2023-06-03 15:04:59.356993	2023-06-03 15:04:59.356993
2	5	4	2023-06-03 15:04:59.410324	2023-06-03 15:04:59.410324
2	6	4	2023-06-03 15:04:59.454317	2023-06-03 15:04:59.454317
2	7	3	2023-06-03 15:04:59.500705	2023-06-03 15:04:59.500705
2	8	1	2023-06-03 15:04:59.542961	2023-06-03 15:04:59.542961
2	9	1	2023-06-03 15:04:59.60417	2023-06-03 15:04:59.60417
3	1	3	2023-06-03 15:04:59.651125	2023-06-03 15:04:59.651125
3	2	1	2023-06-03 15:04:59.701511	2023-06-03 15:04:59.701511
3	3	5	2023-06-03 15:04:59.747328	2023-06-03 15:04:59.747328
3	4	2	2023-06-03 15:04:59.80664	2023-06-03 15:04:59.80664
3	5	4	2023-06-03 15:04:59.854613	2023-06-03 15:04:59.854613
3	6	1	2023-06-03 15:04:59.902752	2023-06-03 15:04:59.902752
3	7	3	2023-06-03 15:04:59.955019	2023-06-03 15:04:59.955019
3	8	4	2023-06-03 15:05:00.001112	2023-06-03 15:05:00.001112
3	9	4	2023-06-03 15:05:00.048221	2023-06-03 15:05:00.048221
4	1	3	2023-06-03 15:05:00.096247	2023-06-03 15:05:00.096247
4	2	5	2023-06-03 15:05:00.155801	2023-06-03 15:05:00.155801
4	3	2	2023-06-03 15:05:00.207717	2023-06-03 15:05:00.207717
4	4	3	2023-06-03 15:05:00.262954	2023-06-03 15:05:00.262954
4	5	2	2023-06-03 15:05:00.325936	2023-06-03 15:05:00.325936
4	6	3	2023-06-03 15:05:00.370965	2023-06-03 15:05:00.370965
4	7	3	2023-06-03 15:05:00.421356	2023-06-03 15:05:00.421356
4	8	3	2023-06-03 15:05:00.467195	2023-06-03 15:05:00.467195
4	9	2	2023-06-03 15:05:00.521039	2023-06-03 15:05:00.521039
5	1	5	2023-06-03 15:05:00.973659	2023-06-03 15:05:00.973659
5	2	4	2023-06-03 15:05:01.123165	2023-06-03 15:05:01.123165
5	3	4	2023-06-03 15:05:01.166172	2023-06-03 15:05:01.166172
5	4	2	2023-06-03 15:05:01.234344	2023-06-03 15:05:01.234344
6	5	2	2023-06-03 15:05:01.293828	2023-06-03 15:05:01.293828
6	6	1	2023-06-03 15:05:01.33844	2023-06-03 15:05:01.33844
6	7	4	2023-06-03 15:05:01.395272	2023-06-03 15:05:01.395272
6	8	4	2023-06-03 15:05:01.538965	2023-06-03 15:05:01.538965
6	9	3	2023-06-03 15:05:01.634339	2023-06-03 15:05:01.634339
6	4	2	2023-06-03 15:05:01.73741	2023-06-03 15:05:01.73741
6	3	2	2023-06-03 15:05:01.796257	2023-06-03 15:05:01.796257
6	2	2	2023-06-03 15:05:01.859209	2023-06-03 15:05:01.859209
6	1	1	2023-06-03 15:05:01.99912	2023-06-03 15:05:01.99912
\.


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.roles (role_id, role_name, created_at, updated_at) FROM stdin;
1	Admin	2023-06-03 15:05:02.050987	2023-06-03 15:05:02.050987
2	Teaching Staff	2023-06-03 15:05:02.126262	2023-06-03 15:05:02.126262
3	Teacher	2023-06-03 15:05:02.182957	2023-06-03 15:05:02.182957
4	Student	2023-06-03 15:05:02.234988	2023-06-03 15:05:02.234988
\.


--
-- Data for Name: set_question; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.set_question (set_question_id, part_id, title, numeric_order, audio, created_at, updated_at) FROM stdin;
1	1		1	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_1.mp3	2023-06-03 23:24:26.565192	2023-06-03 23:24:26.565192
2	1		2	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_2.mp3	2023-06-03 23:24:26.607994	2023-06-03 23:24:26.607994
3	1		3	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_3.mp3	2023-06-03 23:24:26.651163	2023-06-03 23:24:26.651163
4	1		4	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_4.mp3	2023-06-03 23:24:26.694423	2023-06-03 23:24:26.694423
5	1		5	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_5.mp3	2023-06-03 23:24:26.779566	2023-06-03 23:24:26.779566
6	1		6	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_6.mp3	2023-06-03 23:24:26.873159	2023-06-03 23:24:26.873159
7	2		1	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_7.mp3	2023-06-03 23:24:26.926052	2023-06-03 23:24:26.926052
8	2		2	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_8.mp3	2023-06-03 23:24:26.974949	2023-06-03 23:24:26.974949
9	2		3	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_9.mp3	2023-06-03 23:24:27.021475	2023-06-03 23:24:27.021475
10	2		4	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_10.mp3	2023-06-03 23:24:27.064322	2023-06-03 23:24:27.064322
11	2		5	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_11.mp3	2023-06-03 23:24:27.107503	2023-06-03 23:24:27.107503
12	2		6	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_12.mp3	2023-06-03 23:24:27.15114	2023-06-03 23:24:27.15114
13	2		7	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_13.mp3	2023-06-03 23:24:27.218984	2023-06-03 23:24:27.218984
14	2		8	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_14.mp3	2023-06-03 23:24:27.281512	2023-06-03 23:24:27.281512
15	2		9	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_15.mp3	2023-06-03 23:24:27.324125	2023-06-03 23:24:27.324125
16	2		10	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_16.mp3	2023-06-03 23:24:27.372337	2023-06-03 23:24:27.372337
17	2		11	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_17.mp3	2023-06-03 23:24:27.414926	2023-06-03 23:24:27.414926
18	2		12	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_18.mp3	2023-06-03 23:24:27.457504	2023-06-03 23:24:27.457504
19	2		13	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_19.mp3	2023-06-03 23:24:27.500977	2023-06-03 23:24:27.500977
20	2		14	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_20.mp3	2023-06-03 23:24:27.579174	2023-06-03 23:24:27.579174
21	2		15	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_21.mp3	2023-06-03 23:24:27.623387	2023-06-03 23:24:27.623387
22	2		16	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_22.mp3	2023-06-03 23:24:27.667718	2023-06-03 23:24:27.667718
23	2		17	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_23.mp3	2023-06-03 23:24:27.718388	2023-06-03 23:24:27.718388
24	2		18	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_24.mp3	2023-06-03 23:24:27.760882	2023-06-03 23:24:27.760882
25	2		19	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_25.mp3	2023-06-03 23:24:27.804704	2023-06-03 23:24:27.804704
26	2		20	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_26.mp3	2023-06-03 23:24:27.859011	2023-06-03 23:24:27.859011
27	2		21	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_27.mp3	2023-06-03 23:24:27.943066	2023-06-03 23:24:27.943066
28	2		22	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_28.mp3	2023-06-03 23:24:27.988902	2023-06-03 23:24:27.988902
29	2		23	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_29.mp3	2023-06-03 23:24:28.041274	2023-06-03 23:24:28.041274
30	2		24	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_30.mp3	2023-06-03 23:24:28.093576	2023-06-03 23:24:28.093576
31	2		25	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_31.mp3	2023-06-03 23:24:28.14456	2023-06-03 23:24:28.14456
32	3		1	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_32_34.mp3	2023-06-03 23:24:28.190258	2023-06-03 23:24:28.190258
33	3		2	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_35_37.mp3	2023-06-03 23:24:28.24463	2023-06-03 23:24:28.24463
34	3		3	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_38_40.mp3	2023-06-03 23:24:28.320792	2023-06-03 23:24:28.320792
35	3		4	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_41_43.mp3	2023-06-03 23:24:28.365013	2023-06-03 23:24:28.365013
36	3		5	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_44_46.mp3	2023-06-03 23:24:28.408143	2023-06-03 23:24:28.408143
37	3		6	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_47_49.mp3	2023-06-03 23:24:28.451162	2023-06-03 23:24:28.451162
38	3		7	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_50_52.mp3	2023-06-03 23:24:28.495068	2023-06-03 23:24:28.495068
39	3		8	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_53_55.mp3	2023-06-03 23:24:28.537499	2023-06-03 23:24:28.537499
40	3		9	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_56_58.mp3	2023-06-03 23:24:28.583563	2023-06-03 23:24:28.583563
41	3		10	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_59_61.mp3	2023-06-03 23:24:28.631018	2023-06-03 23:24:28.631018
42	3		11	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_62_64.mp3	2023-06-03 23:24:28.683176	2023-06-03 23:24:28.683176
43	3		12	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_65_67.mp3	2023-06-03 23:24:28.751061	2023-06-03 23:24:28.751061
44	3		13	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_68_70.mp3	2023-06-03 23:24:28.796544	2023-06-03 23:24:28.796544
45	4		1	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_71_73.mp3	2023-06-03 23:24:28.860079	2023-06-03 23:24:28.860079
46	4		2	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_74_76.mp3	2023-06-03 23:24:28.903315	2023-06-03 23:24:28.903315
47	4		3	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_77_79.mp3	2023-06-03 23:24:28.946314	2023-06-03 23:24:28.946314
48	4		4	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_80_82.mp3	2023-06-03 23:24:28.992032	2023-06-03 23:24:28.992032
49	4		5	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_83_85.mp3	2023-06-03 23:24:29.055387	2023-06-03 23:24:29.055387
50	4		6	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_86_88.mp3	2023-06-03 23:24:29.101494	2023-06-03 23:24:29.101494
51	4		7	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_89_91.mp3	2023-06-03 23:24:29.153046	2023-06-03 23:24:29.153046
52	4		8	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_92_94.mp3	2023-06-03 23:24:29.200658	2023-06-03 23:24:29.200658
53	4		9	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_95_97.mp3	2023-06-03 23:24:29.254938	2023-06-03 23:24:29.254938
54	4		10	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_98_100.mp3	2023-06-03 23:24:29.317715	2023-06-03 23:24:29.317715
55	5		1	\N	2023-06-03 23:24:29.410163	2023-06-03 23:24:29.410163
56	5		2	\N	2023-06-03 23:24:29.455003	2023-06-03 23:24:29.455003
57	5		3	\N	2023-06-03 23:24:29.500594	2023-06-03 23:24:29.500594
58	5		4	\N	2023-06-03 23:24:29.542744	2023-06-03 23:24:29.542744
59	5		5	\N	2023-06-03 23:24:29.592703	2023-06-03 23:24:29.592703
60	5		6	\N	2023-06-03 23:24:29.638959	2023-06-03 23:24:29.638959
61	5		7	\N	2023-06-03 23:24:29.683692	2023-06-03 23:24:29.683692
62	5		8	\N	2023-06-03 23:24:29.747188	2023-06-03 23:24:29.747188
63	5		9	\N	2023-06-03 23:24:29.796897	2023-06-03 23:24:29.796897
64	5		10	\N	2023-06-03 23:24:29.870728	2023-06-03 23:24:29.870728
65	5		11	\N	2023-06-03 23:24:29.916637	2023-06-03 23:24:29.916637
66	5		12	\N	2023-06-03 23:24:29.958705	2023-06-03 23:24:29.958705
67	5		13	\N	2023-06-03 23:24:30.004474	2023-06-03 23:24:30.004474
68	5		14	\N	2023-06-03 23:24:30.049459	2023-06-03 23:24:30.049459
69	5		15	\N	2023-06-03 23:24:30.094063	2023-06-03 23:24:30.094063
70	5		16	\N	2023-06-03 23:24:30.142947	2023-06-03 23:24:30.142947
71	5		17	\N	2023-06-03 23:24:30.190819	2023-06-03 23:24:30.190819
72	5		18	\N	2023-06-03 23:24:30.245559	2023-06-03 23:24:30.245559
73	5		19	\N	2023-06-03 23:24:30.313657	2023-06-03 23:24:30.313657
74	5		20	\N	2023-06-03 23:24:30.358953	2023-06-03 23:24:30.358953
75	5		21	\N	2023-06-03 23:24:30.404085	2023-06-03 23:24:30.404085
76	5		22	\N	2023-06-03 23:24:30.446433	2023-06-03 23:24:30.446433
77	5		23	\N	2023-06-03 23:24:30.491617	2023-06-03 23:24:30.491617
78	5		24	\N	2023-06-03 23:24:30.541941	2023-06-03 23:24:30.541941
79	5		25	\N	2023-06-03 23:24:30.58935	2023-06-03 23:24:30.58935
80	5		26	\N	2023-06-03 23:24:30.710054	2023-06-03 23:24:30.710054
81	5		27	\N	2023-06-03 23:24:30.782521	2023-06-03 23:24:30.782521
82	5		28	\N	2023-06-03 23:24:30.844633	2023-06-03 23:24:30.844633
83	5		29	\N	2023-06-03 23:24:30.902986	2023-06-03 23:24:30.902986
84	5		30	\N	2023-06-03 23:24:31.034656	2023-06-03 23:24:31.034656
85	6	refer to the following notice.	1	\N	2023-06-03 23:24:31.090984	2023-06-03 23:24:31.090984
86	6	refer to the following customer review.	2	\N	2023-06-03 23:24:31.139006	2023-06-03 23:24:31.139006
87	6	refer to the following letter.	3	\N	2023-06-03 23:24:31.189723	2023-06-03 23:24:31.189723
88	6	refer to the following e-mail.	4	\N	2023-06-03 23:24:31.232189	2023-06-03 23:24:31.232189
89	7	refer to the following Web page.	1	\N	2023-06-03 23:24:31.342354	2023-06-03 23:24:31.342354
90	7	refer to the following job advertisement.	2	\N	2023-06-03 23:24:31.389589	2023-06-03 23:24:31.389589
91	7	refer to the following report.	3	\N	2023-06-03 23:24:31.432055	2023-06-03 23:24:31.432055
92	7	refer to the following e-mail.	4	\N	2023-06-03 23:24:31.538952	2023-06-03 23:24:31.538952
93	7	refer to the following article.	5	\N	2023-06-03 23:24:31.634328	2023-06-03 23:24:31.634328
94	7	refer to the following text-message chain.	6	\N	2023-06-03 23:24:31.676918	2023-06-03 23:24:31.676918
95	7	refer to the following e-mail.	7	\N	2023-06-03 23:24:31.727173	2023-06-03 23:24:31.727173
96	7	refer to the following information.	8	\N	2023-06-03 23:24:31.834325	2023-06-03 23:24:31.834325
97	7	refer to the following letter.	9	\N	2023-06-03 23:24:31.934661	2023-06-03 23:24:31.934661
98	7	refer to the following online chat discussion.	10	\N	2023-06-03 23:24:32.034334	2023-06-03 23:24:32.034334
99	7	refer to the following article and letter.	11	\N	2023-06-03 23:24:32.082771	2023-06-03 23:24:32.082771
100	7	refer to the following Web page and review.	12	\N	2023-06-03 23:24:32.133064	2023-06-03 23:24:32.133064
101	7	refer to the following e-mails and notice.	13	\N	2023-06-03 23:24:32.234331	2023-06-03 23:24:32.234331
102	7	refer to the following article, e-mail, and plan.	14	\N	2023-06-03 23:24:32.334408	2023-06-03 23:24:32.334408
103	7	refer to the following e-mails and price list.	15	\N	2023-06-03 23:24:32.377801	2023-06-03 23:24:32.377801
\.


--
-- Data for Name: side; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.side (side_id, set_question_id, paragraph, seq, created_at, updated_at) FROM stdin;
1	1	<p><strong>1. M-Au</strong></p><p><strong>(A) He's parking a truck.</strong></p><p>(B) He's lifting some furniture.</p><p>(C) He's starting an engine.</p><p>(D) He's driving a car.</p>	1	2023-06-03 23:25:27.865525	2023-06-03 23:25:27.865525
2	1	<p>https://study4.com/media/tez_media1/img/ets_toeic_2022_test_1_1.png</p>	2	2023-06-03 23:25:27.961651	2023-06-03 23:25:27.961651
3	2	<p><strong>2. W-Br</strong></p><p>(A) Some curtains have been closed.</p><p>(B) Some jackets have been laid on a chair.</p><p><strong>(C) Some people are gathered around a desk.</strong></p><p>(D) Someone is turning on a lamp.</p>	1	2023-06-03 23:25:28.006955	2023-06-03 23:25:28.006955
4	2	<p>https://study4.com/media/tez_media1/img/ets_toeic_2022_test_1_2.png</p>	2	2023-06-03 23:25:28.06296	2023-06-03 23:25:28.06296
5	3	<p><strong>3. M-Cn</strong></p><p>(A) One of the women is reaching into her bag.</p><p><strong>(B) The women are waiting in a line.</strong></p><p>(C) The man is leading a tour group.</p><p>(D) The man is opening a cash register.</p>	1	2023-06-03 23:25:28.105964	2023-06-03 23:25:28.105964
6	3	<p>https://study4.com/media/tez_media1/img/ets_toeic_2022_test_1_3.png</p>	2	2023-06-03 23:25:28.150535	2023-06-03 23:25:28.150535
7	4	<p><strong>4. W-Am</strong></p><p><strong>(A) The man is bending over a bicycle.</strong></p><p>(B) A wheel has been propped against a stack of bricks.</p><p>(C) The man is collecting some pieces of wood.</p><p>(D) A handrail is being installed.</p>	1	2023-06-03 23:25:28.212168	2023-06-03 23:25:28.212168
8	4	<p>https://study4.com/media/tez_media1/img/ets_toeic_2022_test_1_4.png</p>	2	2023-06-03 23:25:28.257945	2023-06-03 23:25:28.257945
9	5	<p><strong>5. M-Am</strong></p><p>(A) An armchair has been placed under a window.</p><p>(B) Some reading materials have fallen on the floor.</p><p>(C) Some flowers are being watered.</p><p><strong>(D) Some picture frames are hanging on a wall.</strong></p>	1	2023-06-03 23:25:28.351153	2023-06-03 23:25:28.351153
10	5	<p>https://study4.com/media/tez_media1/img/ets_toeic_2022_test_1_5.png</p>	2	2023-06-03 23:25:28.40114	2023-06-03 23:25:28.40114
11	6	<p><strong>6. W-Br</strong></p><p>(A) She's adjusting the height of an umbrella.</p><p>(B) She's inspecting the tires on a vending cart.</p><p><strong>(C) There's a mobile food stand on a walkway.</strong></p><p>(D) There are some cooking utensils on the ground.</p>	1	2023-06-03 23:25:28.445234	2023-06-03 23:25:28.445234
12	6	<p>https://study4.com/media/tez_media1/img/ets_toeic_2022_test_1_6.png</p>	2	2023-06-03 23:25:28.490444	2023-06-03 23:25:28.490444
13	7	<p><strong>M-Au:</strong> Why was this afternoon's meeting canceled?</p><p><strong>W-Br:</strong></p><p>(A) Room 206, I think.</p><p><strong>(B) Because the manager is out of the office.</strong></p><p>(C) Let's review the itinerary for our trip.</p>	1	2023-06-03 23:25:28.542946	2023-06-03 23:25:28.542946
14	8	<p><strong>W-Br:</strong> You use the company fitness center, don't you?</p><p><strong>M-Cn:</strong></p><p><strong>(A) Yes, every now and then.</strong></p><p>(B) Please center the text on the page.</p><p>(C) I think it fits you well.</p>	1	2023-06-03 23:25:28.592723	2023-06-03 23:25:28.592723
15	9	<p><strong>W-Am:</strong> Do you have the images from the graphics department?</p><p><strong>M-Au:</strong></p><p>(A) OK, that won't be a problem.</p><p>(B) A high-definition camera.</p><p><strong>(C) No, they're not ready yet.</strong></p>	1	2023-06-03 23:25:28.638622	2023-06-03 23:25:28.638622
16	10	<p><strong>M-Cn:</strong> When are you moving to your new office?</p><p><strong>W-Am:</strong></p><p>(A) The office printer over there.</p><p>(B) The water bill is high this month.</p><p><strong>(C) The schedule is being revised.</strong></p>	1	2023-06-03 23:25:28.690807	2023-06-03 23:25:28.690807
17	11	<p><strong>W-Am:</strong> Would you like to sign up for the company retreat?</p><p><strong>M-Au:</strong></p><p><strong>(A) Sure, I'll write my name down.</strong></p><p>(B) Twenty people, maximum.</p><p>(C) Can replace the sign?</p>	1	2023-06-03 23:25:28.742398	2023-06-03 23:25:28.742398
18	12	<p><strong>M-Cn:</strong> How often do have to submit my time sheet?</p><p><strong>W-Br:</strong></p><p>(A) Five sheets of paper.</p><p><strong>(B) You need to do it once a week.</strong></p><p>(C) No, I don't usually wear a watch.</p>	1	2023-06-03 23:25:28.793658	2023-06-03 23:25:28.793658
19	13	<p><strong>W-Br:</strong> I can buy a monthly gym membership, right?</p><p><strong>M-Cn:</strong></p><p>(A) A very popular exercise routine.</p><p>(B) The exercise room is on your right.</p><p><strong>(C) Yes, at the front desk.</strong></p>	1	2023-06-03 23:25:28.837283	2023-06-03 23:25:28.837283
20	14	<p><strong>M-Au:</strong> Have you put price tags on all the clearance items?</p><p><strong>W-Am:</strong></p><p><strong>(A) Yes, everything's been labeled.</strong></p><p>(B) It is a little cloudy.</p><p>(C) Where is your name tag?</p>	1	2023-06-03 23:25:28.932621	2023-06-03 23:25:28.932621
21	15	<p><strong>W-Br:</strong> Don't we still need to change the newspaper layout?</p><p><strong>M-Cn:</strong></p><p>(A) Down the hall on your right.</p><p><strong>(B) No, it's already been changed.</strong></p><p>(C) A new computer program.</p>	1	2023-06-03 23:25:28.981804	2023-06-03 23:25:28.981804
22	16	<p><strong>W-Br:</strong> What's the total cost of the repair work?</p><p><strong>W-Am:</strong></p><p><strong>(A) It's free because of the warranty.</strong></p><p>(B) I have some boxes you can use.</p><p>(C) In a couple of hours.</p>	1	2023-06-03 23:25:29.029298	2023-06-03 23:25:29.029298
23	17	<p><strong>W-Am:</strong> Where can I get a new filing cabinet?</p><p><strong>M-Au:</strong></p><p>(A) All of the cabins have been rented.</p><p>(B) I'll put the tiles in the corner.</p><p><strong>(C) All furniture requests must be approved first.</strong></p>	1	2023-06-03 23:25:29.072778	2023-06-03 23:25:29.072778
24	18	<p><strong>M-Cn:</strong> How do reset my password?</p><p><strong>W-Am:</strong></p><p>(A) By the end of the month.</p><p><strong>(B) You should call the help desk.</strong></p><p>(C) Thanks for setting the table.</p>	1	2023-06-03 23:25:29.124518	2023-06-03 23:25:29.124518
25	19	<p><strong>M-Au:</strong> Could you check to see if that monitor is plugged in?</p><p><strong>M-Cn:</strong></p><p>(A) I didn't send them yet.</p><p>(B) A longer power cord.</p><p><strong>(C) Do you want me to check them all?</strong></p>	1	2023-06-03 23:25:29.172833	2023-06-03 23:25:29.172833
26	20	<p><strong>M-Cn:</strong> Is the new inventory process more efficient?</p><p><strong>W-Br:</strong></p><p><strong>(A) It only took me an hour.</strong></p><p>(B) Yes, she's new here.</p><p>(C) I'll have the fish.</p>	1	2023-06-03 23:25:29.22103	2023-06-03 23:25:29.22103
27	21	<p><strong>M-Au:</strong> Would you like some ice cream or cake for dessert?</p><p><strong>W-Am:</strong></p><p>(A) Because I'm hungry.</p><p>(B) Yes, I liked it.</p><p><strong>(C) I'm trying to avoid sugar.</strong></p>	1	2023-06-03 23:25:29.264159	2023-06-03 23:25:29.264159
28	22	<p><strong>W-Br:</strong> Who's doing the product demonstration this afternoon?</p><p><strong>M-Au:</strong></p><p>(A) That bus station is closed, sorry.</p><p><strong>(B) I'm leaving for New York at lunchtime.</strong></p><p>(C) Let me show you a few more.</p>	1	2023-06-03 23:25:29.314966	2023-06-03 23:25:29.314966
29	23	<p><strong>M-Cn:</strong> Your presentation's being reviewed at today's managers' meeting.</p><p><strong>W-Br:</strong></p><p><strong>(A) I didn't have much time to complete it.</strong></p><p>(B) Next slide, please.</p><p>(C) That movie had great reviews.</p>	1	2023-06-03 23:25:29.359011	2023-06-03 23:25:29.359011
30	24	<p><strong>W-Br:</strong> Don't you carry these shoes in red?</p><p><strong>M-Au:</strong></p><p>(A) I'll lift from this end.</p><p><strong>(B) There's a new shipment coming tomorrow.</strong></p><p>(C) I have time to read it now.</p>	1	2023-06-03 23:25:29.406981	2023-06-03 23:25:29.406981
31	25	<p><strong>W-Am:</strong> Would you like to have lunch with the clients?</p><p><strong>M-Cn:</strong></p><p>(A) About a three-hour flight.</p><p>(B) The first stage of the project.</p><p><strong>(C) Sure, we can go to the café downstairs.</strong></p>	1	2023-06-03 23:25:29.493554	2023-06-03 23:25:29.493554
32	26	<p><strong>M-Au:</strong> How about hiring an event planner to organize the holiday party?</p><p><strong>W-Br:</strong></p><p>(A) I think it's on the lower shelf.</p><p>(B) Sure, I'd love to attend.</p><p><strong>(C) There's not much money in the budget.</strong></p>	1	2023-06-03 23:25:29.549234	2023-06-03 23:25:29.549234
33	27	<p><strong>M-Cn:</strong> Isn't that carmaker planning to start exporting electric cars?</p><p><strong>W-Am:</strong></p><p><strong>(A) Yes, I've heard that's the plan.</strong></p><p>(B) A ticket to next year's car show.</p><p>(C) Congratulations on your promotion!</p>	1	2023-06-03 23:25:29.593393	2023-06-03 23:25:29.593393
34	28	<p><strong>W-Am:</strong> David trained the interns to use the company database, didn't he?&nbsp;</p><p><strong>M-Cn:</strong></p><p><strong>(A) Actually, it was Hillary.</strong></p><p>(B) An internal audit.</p><p>(C) He's good company.</p>	1	2023-06-03 23:25:29.638963	2023-06-03 23:25:29.638963
35	29	<p><strong>M-Au:</strong> Who's responsible for researching the housing market in India?&nbsp;</p><p><strong>W-Br:</strong></p><p><strong>(A) The senior director is heading up that team.</strong></p><p>(B) Every morning at ten o'clock.</p><p>(C) Yes, it's on Main Street.</p>	1	2023-06-03 23:25:29.708939	2023-06-03 23:25:29.708939
36	30	<p><strong>W-Am:</strong> Have you arranged a ride to take us to the convention center, or should I?&nbsp;</p><p><strong>M-Au:</strong></p><p>(A) Unfortunately, there isn't an extra bag.</p><p>(B) I don't have the phone number for the taxi service.</p><p><strong>(C) We've accepted credit cards before.</strong></p>	1	2023-06-03 23:25:29.752584	2023-06-03 23:25:29.752584
37	31	<p><strong>M-Cn:</strong> These purchases should have been entered on your expense report.&nbsp;</p><p><strong>W-Br:</strong></p><p>(A) No thanks, I don't need anything from the store.</p><p>(B) The entrance is on Thirty-First Street.</p><p><strong>(C) I thought I had until Friday to do that.</strong></p>	1	2023-06-03 23:25:29.801504	2023-06-03 23:25:29.801504
38	32	<p><strong>W-Br</strong> Hi, it's Martina from Accounting. <strong>(32, 33) l'd like to reserve the main conference room for a meeting I'll be leading on Friday with colleagues from our New York office.</strong></p><p><strong>M-Cn</strong> Sure, that shouldn't be a problem. <strong>(33) What time is the meeting?</strong></p><p><strong>W-Br</strong> It's from nine to eleven A.M.</p><p><strong>M-Cn</strong> OK <strong>(33) I'll block off that time slot for you. Do you need any special equipment besides a laptop and projector?</strong></p><p><strong>W-Br</strong> No, but <strong>(34) I'll need the key so I can go in a little early and set up. Can pick that up on Friday morning?</strong></p><p><strong>M-Cn</strong> Absolutely.</p>	1	2023-06-03 23:25:29.849537	2023-06-03 23:25:29.849537
39	33	<p><strong>W-Am</strong> Satoshi, <strong>(35) have you already started working on the budget for next year?</strong></p><p><strong>M-Au</strong> Not yet... but I do plan to start it in the next day or so.</p><p><strong>W-Am</strong> OK, perfect. <strong>(36) I'd like to add some new engineers to my team next year if we can afford it.</strong> thought one might be enough, but I realized we'll probably need three to handle our company's new contracts.</p><p><strong>M-Au</strong> No problem. I can include that in the budget. <strong>(37) I'll just need the details about the positions, including the job titles and expected salaries. Could you send that to me?</strong></p>	1	2023-06-03 23:25:29.966944	2023-06-03 23:25:29.966944
40	34	<p><strong>M-Cn</strong> Welcome to Business Suit Outlet. How can I help you?</p><p><strong>W-Br </strong>Hello. <strong>(38) I'm interviewing for a job next week, and I wanted to buy a new suit.</strong></p><p><strong>M-Cn</strong> Congratulations! Do you have anything particular in mind?</p><p><strong>W-Br</strong> Well, <strong>(39) there's one in your display window that looks nice. But I don't really like the color...</strong></p><p><strong>M-Cn</strong> That one only comes in black. But we do have suits in other colors that are fashionable and appropriate for business.</p><p><strong>W-Br</strong> OK. I can only spend 150 dollars, and I'd like a style similar to the one in the window.</p><p><strong>M-Cn</strong> Let me show you some suits in that price range. By the way, <strong>(40) any alterations needed for the suit are included in the price.</strong></p>	1	2023-06-03 23:25:30.015252	2023-06-03 23:25:30.015252
41	35	<p><strong>W-Br</strong> Ellenville Public Library. How can I help you?</p><p><strong>M-Cn</strong> Hi, I'm calling from the company Grover and James. <strong>(41) We're interested in filming a scene for a movie in the lobby of the library.</strong> Its historic architecture is just what we're looking for.</p><p><strong>W-Br</strong> Well... <strong>(42) we actually had a film shoot in a our library last year. And the thing is... they said it would take one day and it ended up taking three. I'm concerned that will happen again.</strong></p><p><strong>M-Cn</strong> I understand, but this is a very short scene.</p><p><strong>W-Br </strong>Well, <strong>(43) we have a board meeting here next week. I could give you ten minutes at the beginning to give us the details.</strong></p>	1	2023-06-03 23:25:30.062939	2023-06-03 23:25:30.062939
42	36	<p><strong>M-Au</strong> Excuse me, <strong>(44) I'm looking for Axel Schmidt's painting titled The Tulips.</strong></p><p><strong>W-Am</strong> Unfortunately, his paintings aren't on display. But it's just temporary <strong>(45) we're putting new flooring in that gallery.</strong> If you come back in a couple of weeks, the floors will be done, and you can see all of Schmidt's artwork.</p><p><strong>M-Au</strong> Oh, that's too bad. really wanted to see that painting.</p><p><strong>W-Am</strong> I'm sorry about that. But <strong>(46) we sell items featuring that painting in the gift shop. You could buy a souvenir sO you could enjoy The Tulips every day!</strong></p>	1	2023-06-03 23:25:30.109091	2023-06-03 23:25:30.109091
43	37	<p><strong>W-Br</strong> Hey, Dmitry. <strong>(47) Are you still working on your sales report? Collecting all the data from the car dealerships in my region is taking me such a long time.</strong> Especially because this year management wants additional information on vehicle purchases, like model and color...</p><p><strong>M-Au</strong> <strong>(48) Are you using the sales computation software? That's what I used for my report, and it worked really well.</strong></p><p><strong>W-Br</strong> Oh- <strong>(48) you already finished it?</strong></p><p><strong>M-Au</strong> Well-I'm done collecting and analyzing the data, but <strong>(49) I'm having trouble with the presentation. We didn't get any guidelines for that.</strong></p><p><strong>W-Br</strong> <strong>(49) Remember Julie's presentation last year? It was very impressive.</strong> The slides are available on our company intranet.</p>	1	2023-06-03 23:25:30.152837	2023-06-03 23:25:30.152837
44	38	<p><strong>W-Am</strong> Thanks for coming in, Omar. <strong>(50) You might've heard that Rosa Garcia is retiring at the end of November. This means her position as director of information security in Singapore will be vacant.</strong> I'd like to know if you'd be interested.</p><p><strong>M-Cn</strong> Oh! That would be a promotion for me. Well, hmm. I'll need a little time to think about it and talk t over with my family. <strong>(51) I do have a question. When would I start the position?</strong></p><p><strong>W-Am</strong> The first week of December ideally. <strong>(52) We'd pay for all your moving expenses, of course.</strong> If you decide to accept the offer.</p>	1	2023-06-03 23:25:30.196096	2023-06-03 23:25:30.196096
45	39	<p><strong>M-Cn</strong> Maryam, <strong>(53) did you hear that our construction company won the bid to build the river dam next to Burton City?</strong></p><p><strong>W-Br</strong> I did! This is such a major project for us... <strong>(54) the dam's expected to produce enough electricity to power all of Burton.</strong></p><p><strong>M-Cn</strong> Right. Say, do you know when construction will begin?</p><p><strong>W-Br</strong> I don't, but here comes the project manager now. He may have a better idea... <strong>(55) Gerhard, are there any updates on the dam construction?</strong></p><p><strong>M-Au</strong> Well, <strong>(55) we're going to have to wait until the all permits are approved.</strong> It'll be a while before anything else can happen.</p>	1	2023-06-03 23:25:30.254959	2023-06-03 23:25:30.254959
46	40	<p><strong>M-Au</strong> <strong>(56) I have a question about a customer's prescription-he's... oh, I'm sorry. I see you're busy.</strong></p><p><strong>W-Am</strong> I don't have much to do.</p><p><strong>M-Au</strong> <strong>(57) His doctor prescribed a 30-day supply of this allergy medication, but I noticed we only have enough on the shelf for fifteen days.</strong></p><p><strong>W-Am</strong> Our weekly delivery arrives early tomorrow morning. Go ahead and give him the fifteen, and ask him to please come back for the rest. It's allergy season, so a we're selling a lot of that medicine.</p><p><strong>M-Au </strong>Then <strong>(58) maybe we should increase the number of bottles in our next order from the distributor.</strong></p>	1	2023-06-03 23:25:30.319672	2023-06-03 23:25:30.319672
47	41	<p><strong>M-Cn</strong> <strong>(59) Good morning, Ms. Davis. (60) We've received comments from your legal team on the terms and agreements for the travel rewards credit card that we issued.</strong></p><p><strong>M-Au</strong> Could you explain the revisions we need to make to be in compliance with the law?</p><p><strong>W-Am</strong> Sure. <strong>(60) The problem with the agreement is this: it doesn't disclose to users that if a card isn't used for a year, the account will be suspended.</strong></p><p><strong>M-Cn</strong> Oh, that's an oversight on our part. We're glad you caught that.</p><p><strong>W-Am</strong> <strong>(61) We don't want to be fined by banking regulators, so all cardholders will need to be notified by the end of the month.</strong></p>	1	2023-06-03 23:25:30.371165	2023-06-03 23:25:30.371165
48	42	<p><strong>M-Au</strong> Ms. Giordano, it looks like the last of the wedding guests have left. <strong>(62) My staff's going to start packing up our dishes and loading the van.</strong></p><p><strong>W-Br</strong> That's fine, thank you. <strong>(62) The food was delicious. My son and his new wife were very happy with your service.</strong></p><p><strong>M-Au</strong> I'm glad you enjoyed it. And, again, <strong>(63) l'm sorry that some of our waitstaff were late arriving.</strong> They said they drove right past the turnoff.</p><p><strong>W-Br </strong>I understand. The venue is difficult to see from the road. <strong>(64) I really like this location, though, with its view of the mountains from the gardens in the back.</strong></p>	1	2023-06-03 23:25:30.416162	2023-06-03 23:25:30.416162
49	42	<p>https://lh6.googleusercontent.com/AWbPfUpA0bKxy18rFIqOUN4vLDdpAB5aQAd99f09lqW30z5ZUsjQ7zulKtvVYspp7rCPZDWJeIeVS_MVvYjJehGoNdnxSKxaMhy0eVhtRUPFzP8qCWKqG-KAeZZ38wqzajPV1zjOnOOdDI5vtQ</p>	2	2023-06-03 23:25:30.461342	2023-06-03 23:25:30.461342
50	43	<p><strong>W-Am</strong> Hey, Thomas? You like concerts. <strong>(65) Any chance you're interested in the local band showcase this weekend? I have two tickets that I don't need.</strong></p><p><strong>M-Au (65) You got tickets to that? That's surprising! I heard that they sold out in just a few days.</strong></p><p><strong>W-Am</strong> They did, but I actually won these in a radio contest. That's why I'm giving them away instead of selling them. <strong>(66) Good seats, too. Right in the middle, close to the stage.</strong></p><p><strong>M-Au</strong> Sure, I'll take them. Thanks! Why can't you go?</p><p><strong>W-Am (67) This weekend is my parents' anniversary. My sisters and I are planning a party for them at their home in Boston.</strong></p>	1	2023-06-03 23:25:30.505925	2023-06-03 23:25:30.505925
51	43	<p>https://study4.com/media/tez_media1/img/ets_toeic_2022_test_1_65_67.png</p>	2	2023-06-03 23:25:30.556131	2023-06-03 23:25:30.556131
52	44	<p><strong>M-Cn</strong> Hello. <strong>(68) Bellevue Apartments Management Office. Can I help you?</strong></p><p><strong>W-Am</strong> Hi. I'm Azusa Suzuki. <strong>(69) I'm a new tenant here, and live in 2A.</strong></p><p><strong>M-Cn</strong> How's everything in your apartment so far?</p><p><strong>W-Am</strong> Very good. One thing, though... <strong>(69) When can you put my name on the building directory? It still says the previous tenant's name.</strong></p><p><strong>M-Cn</strong> No problem. I can send someone over now. Unit 2A, you said?</p><p><strong>W-Am</strong> Yes. And, <strong>(70) I'll be stopping by your office tomorrow with my February rent check.</strong></p><p><strong>M-Cn</strong> OK. See you then.</p>	1	2023-06-03 23:25:30.61799	2023-06-03 23:25:30.61799
53	44	<p>https://study4.com/media/tez_media1/img/ets_toeic_2022_test_1_68_70.png</p>	2	2023-06-03 23:25:30.663251	2023-06-03 23:25:30.663251
54	45	<p><strong>W-Am</strong> Hello, this is Karen Smith. <strong>(71) I have an appointment with Dr. Miller for my annual eye exam on Tuesday. (72) Unfortunately, I won't be able to make it. If possible, I'd like to reschedule for later in the week.</strong> If Dr. Miller is available in the afternoon, that would work better for me. <strong>(73) I also wanted to ask about your warranty for eyeglasses. What exactly does the warranty cover?</strong> Thank you, and please call me back at 555-0110.</p>	1	2023-06-03 23:25:30.709682	2023-06-03 23:25:30.709682
55	46	<p><strong>M-Cn</strong> <strong>(74) Curious about how chocolate is made? Then come visit us at Bodin's Chocolate Factory!</strong> You'll have a great time. <strong>(74) We offer guided tours every Saturday and Sunday at our factory, located directly across from Appleton Shopping Center.</strong> During your two-hour visit, you'll observe the creation and packaging of Bodin's products. And <strong>(75) each visitor will get their picture taken with Cheery, our adorable chocolate mascot, to take home as a souvenir.</strong> Right now, <strong>(76) with the coupon available on our Web site, you can bring in a group of twelve or more people for half the price. Download yours today!</strong></p>	1	2023-06-03 23:25:30.802041	2023-06-03 23:25:30.802041
56	47	<p><strong>W-Br</strong> Attention, everyone. <strong>(77) Unfortunately, we've had to stop the movie.</strong> As you've probably noticed, <strong>(78) we're having technical difficulties with the audio. I'm very sorry about this</strong>--we take our sound quality seriously and want you to know we'll have technicians here as soon as possible to resolve this issue. As you exit, <strong>(79) please stop by the customer service desk in the lobby to pick up two free tickets for your next movie.</strong> Again, my apologies for the inconvenience.</p>	1	2023-06-03 23:25:30.856042	2023-06-03 23:25:30.856042
57	48	<p><strong>W-Am</strong> <strong>(80) Welcome to Branson Tech's second annual conference on computer security. (81) We decided to try something different to publicize the event this year. We advertised primarily through social media rather than by e-mail newsletters or on company Web sites.</strong> And over 300 people are here! The first presentations will begin in fifteen minutes. The talks will take place in different rooms throughout the building, So <strong>(82) please be sure to check your programs for the list of topics, speakers, and locations.</strong></p>	1	2023-06-03 23:25:30.909874	2023-06-03 23:25:30.909874
58	49	<p><strong>M-Au</strong> Welcome, everyone. <strong>(83) On behalf of the Department of Transportation, I'd like to announce a new experimental program to reduce traffic in Greenville.</strong> Beginning in January, there will be a ten-dollar fee for each car that enters the city. <strong>(84) There will, however, be a lower fee for people who commute to Greenville for work.</strong> They will be asked to pay five dollars rather than ten dollars. These charges are aimed at deterring drivers from coming into this very crowded area. <strong>(85) The program will be in effect for three months. After that, we will determine if the program has decreased traffic congestion enough to continue it permanently.</strong></p>	1	2023-06-03 23:25:30.954958	2023-06-03 23:25:30.954958
59	50	<p><strong>W-Br</strong> Thanks for tuning in to Music Today on Radio 49. First, <strong>(86) a reminder that the Classical Music Festival is this weekend. (87) Radio 49 is giving listeners a chance to win a pair of tickets by entering a contest.</strong> And tickets are almost sold out. Just go to our Web site and tell us what you enjoy most on our station, and we'll pick a winner at random. This year is the tenth anniversary of the event, which was founded by a famous classical musician, Umesh Gupta. <strong>(88) On tomorrow morning's program, Mr. Gupta will be here for an interview about the history of the festival.</strong> Be sure to join us for that.</p>	1	2023-06-03 23:25:30.998469	2023-06-03 23:25:30.998469
60	51	<p><strong>W-Am</strong> Thank you for visiting our booth here at the trade fair. <strong>(89) We're so excited to show you our new patio furniture.</strong> You're probably familiar with our wooden outdoor tables and chairs, and <strong>(90) we want you to know that we've expanded that line to include plastic furniture. This furniture is very durable.</strong> It can withstand any kind of weather and it needs no maintenance. <strong>(91) I'm going to hand out a sample of the plastic material we use. Please pass it around after you've had a chance to look at it.</strong></p>	1	2023-06-03 23:25:31.041912	2023-06-03 23:25:31.041912
61	52	<p><strong>W-Br</strong> <strong>(92) This is Noriko, the human resources supervisor here in Albany. (93) l'm calling about your request to transfer to our branch in Havertown... I know your commute is difficult, and it takes you over an hour to drive to this office. So I've contacted the manager at that location</strong>, and there is a need for a skilled software engineer. There are a few forms that you'll need to fill out, though, to complete the request. <strong>(94) Now we need to talk about your work schedule to decide when you'll start at the new location.</strong> Please call me back.</p>	1	2023-06-03 23:25:31.089283	2023-06-03 23:25:31.089283
62	53	<p><strong>M-Cn</strong> You're listening to Making My Company with Mark Sullivan. <strong>(95) In each episode I invite entrepreneurs from around the world to talk about how they built their successful businesses.</strong> In celebration of our radio show's ten-year anniversary, <strong>(96) our Web site now has all of our previously aired episodes. You can access them with the click of a button.</strong> You can even download them onto mobile devices to listen to on the go! OK, now, welcome Haru Nakamura to the show. <strong>(97) Ms. Nakamura is excited to be here today.</strong></p>	1	2023-06-03 23:25:31.140109	2023-06-03 23:25:31.140109
63	53	<p>https://study4.com/media/tez_media1/img/ets_toeic_2022_test_1_95_97.png</p>	2	2023-06-03 23:25:31.220812	2023-06-03 23:25:31.220812
64	54	<p><strong>M-Au</strong> It's Akira, calling from the district manager's office. The visual merchandising team wants to make a slight change to the fall display standards that we sent you yesterday. <strong>(98) They want to move the shirts with the vertical stripes-hang them instead of having them displayed on the shelf. We'll display some colorful accessories there instead, like scarves and ties.</strong> Also, <strong>(99) hang all the socks on gridwall panels by the cash registers. </strong>Those sell best when people can grab them when they walk up to pay. <strong>(100) The thicker, cold-weather socks will be shipped to you soon. You'll get an e-mail confirmation with the details when they're sent.</strong></p>	1	2023-06-03 23:25:31.338957	2023-06-03 23:25:31.338957
65	54	<p>https://study4.com/media/tez_media1/img/ets_toeic_2022_test_1_98_100.png</p>	2	2023-06-03 23:25:31.434313	2023-06-03 23:25:31.434313
66	85	<p><strong>NOTICE</strong></p><p>&nbsp;</p><p>To continue providing the highest level of <strong>--(131)--</strong> to our corporate tenants, we have scheduled the south lobby restrooms for maintenance this weekend, May 13 and May 14. <strong>--(132)--</strong> this time, the restrooms will be out of order, so tenants and their guests should instead use the facilities in the north lobby.</p><p>&nbsp;</p><p>We <strong>--(133)--</strong> for any inconvenience this might cause. <strong>--(134)--</strong>.</p><p>&nbsp;</p><p>Denville Property Management Partners</p>	1	2023-06-03 23:25:31.538942	2023-06-03 23:25:31.538942
67	86	<p>I recently received a last-minute invitation to a formal dinner. I bought a suit and needed it tailored as <strong>--(135)--</strong> as possible. A friend suggested that I use Antonio's Tailoring Shop in downtown Auckland. When I met Antonio, he gave me his full attention <strong>--(136)--</strong> his shop was busy. He took the time to listen to me and carefully noted all my measurements. He then explained all the tailoring costs up front and assured me that he could have my suit ready in three days, but he had it done in two! <strong>--(137)--</strong>.</p><p>&nbsp;</p><p>Antonio has run his shop for over 30 years, and his experience really shows. He is a <strong>--(138)--</strong> tailor.</p><p>I highly recommend him.<br>&nbsp;</p><p>Jim Kestren, Auckland</p>	1	2023-06-03 23:25:31.634317	2023-06-03 23:25:31.634317
68	87	<p>Dear Director Yoshida,</p><p>&nbsp;</p><p>Thank you for your school's interest in visiting our farm next month. Please note that children must be at least six years old to visit and tour the farm.<strong>--(139)--</strong>. I have enclosed a list of the <strong>--(140)--</strong> activities available for our young visitors. Two of these <strong>--(141)--</strong> must be scheduled in advance. They are a cheese-making class and an introduction to beekeeping. Both are very popular with our visitors.</p><p>&nbsp;</p><p>Please let <strong>--(142)--</strong> know your selection by early next week. I look forward to welcoming your group soon!</p><p>&nbsp;</p><p>Sincerely,<br>&nbsp;</p><p>Annabel Romero, Coordinator</p><p>Merrytree Family Farm</p>	1	2023-06-03 23:25:31.677252	2023-06-03 23:25:31.677252
69	88	<p><strong>To:</strong> Lakshmi Aiyar<br><strong>From:</strong> info@healthonity.com<br><strong>Date:</strong> February 8<br><strong>Subject:</strong> Healthonity Dental</p><p>&nbsp;</p><p>Dear Ms. Aiyar,</p><p>&nbsp;</p><p>We, the dental health professionals of the Healthonity Dental Center, are <strong>--(143)--</strong> to introduce our just-opened practice. We aim to provide access to the largest team of dental specialists in the region. On our Web site, you can see a comprehensive list of the procedures we offer. <strong>--(144)--</strong>. The members of our practice share a passion for helping people maintain beautiful and healthy smiles.</p><p>&nbsp;</p><p>Contact our center today at 305-555-0121 <strong>--(145)--</strong> an initial evaluation. All first-time <strong>--(146)--</strong> will benefit from a 50 percent discount on the cost through the end of the month.</p><p>&nbsp;</p><p>Sincerely,</p><p><br>The Team at Healthonity Dental Center</p>	1	2023-06-03 23:25:31.720242	2023-06-03 23:25:31.720242
70	89	<p>http://www.moonglowairways.com.au</p><p><strong>Special Announcement by Geoff Clifford, President of Moon Glow Airways</strong><br>&nbsp;</p><p>As many of you are aware, there was a problem with Pelman Technology, the system that handles our airline reservations. This outage has affected several airlines. It's been a rough week, but the good news is it that it has been repaired, and we are re-setting our system. However, Moon Glow passengers may still face delays for day or two. This most likely will include longer lines at airports. We have added more on-site customer service representatives at airports in all of our destination cities to assist customers with their flights and information. We appreciate your understanding and patience.</p>	1	2023-06-03 23:25:31.781102	2023-06-03 23:25:31.781102
71	90	<p><strong>Video Captioners --- Work from Home</strong></p><p>Kiesel Video is seeking detail-oriented people to use our software to add text captions to a wide variety of video material, such as television programs, movies, and university lectures. We will provide free online training. Successful applicants must possess strong language skills and have a computer, a headset, and high-speed Internet access.</p><p>The position features:</p><p>- Flexible hours--you work as much or as little as you want.</p><p>- Choice of projects-we have work in many types of content.</p><p>- Good pay - our captioners earn $350 to $1,100 a week, depending on the assignment.</p><p>Apply today at www.kieselvideo.com/jobs</p>	1	2023-06-03 23:25:31.824492	2023-06-03 23:25:31.824492
72	91	<p>February 1</p><p>&nbsp;</p><p>SOFTWARE TESTING REPORT</p><p>&nbsp;</p><p>Version of Software Program: Konserted 2.5</p><p>Testing Dates: January 10-12</p><p>Number of Participants: 8</p><p>&nbsp;</p><p>Software Testing Overview: Participants were asked to complete a series of tasks testing the functionality of the revised Konserted interface. In task number 1, participants searched for a concert in a designated area. In task number 2, participants searched for new friends on the site. In task number 3, participants invited friends to a concert. In task number 4, participants posted concert reviews, photos, and videos.&nbsp;<br>&nbsp;</p><p>Initial Findings: Task number 3 proved the most challenging, with three participants unable to complete it in under two minutes. A potential cause for this difficulty may be the choice of icons in the menu bar. Clearer, more intuitive icons could make this task easier to complete for participants.</p>	1	2023-06-03 23:25:31.934321	2023-06-03 23:25:31.934321
73	92	<p><strong>*E-mail*</strong></p><p>&nbsp;</p><p>To: catiyeh@mymailroom.au<br>From: achen@mutamark.au<br>Date: 1 July<br>Subject: Mutamark conference</p><p>&nbsp;</p><p>Dear Ms. Atiyeh,</p><p>&nbsp;</p><p>To follow up on our phone conversation earlier today, I would like to extend to you a formal written invitation to speak at the eighth annual Mutamark conference, scheduled to take place this year from 17 to 20 September in Zagros. Because you drew a sizeable crowd when you appeared at the conference in the past, we will be making special arrangements for your visit this time. The Blue Room at the Debeljak Hotel holds only 120, so this year we are also booking the Koros Hall, which has a capacity of 270. We can offer you a 40-to-50-minute slot on the last day of the conference, when attendance should be at its peak. Please e-mail me to confirm your acceptance and to let me know more about your audiovisual requirements. We can provide overhead projection for still images if you will be using them again.</p><p>&nbsp;</p><p>Very best regards,</p><p><br>Alex Chen, Conference Planning<br>Mutamark Headquarters, Melbourne</p>	1	2023-06-03 23:25:31.983208	2023-06-03 23:25:31.983208
74	93	<p><strong>Monorail Coming to Sudbury</strong></p><p>(4 Feb.) Ottawa-based Saenger, Inc., has been selected by the city of Sudbury to build a monorail system that will connect the city's commercial district to the airport. <strong>-[1]-</strong>. Funding for the system is drawn from a combination of public agencies and private investors. <strong>-[2]-</strong>. Ticket sales for the monorail will also provide a new source of revenue for the city. <strong>-[3]-</strong>. Construction is slated to begin in early June and is expected to be completed within four years. <strong>-[4]-</strong></p>	1	2023-06-03 23:25:32.025884	2023-06-03 23:25:32.025884
75	94	<p><strong>Dennis Beck (2:52 P.M.)</strong></p><p>Hi, Corinne. I just want to be sure that you saw the document I sent you. It's the combined market analysis and advertising proposal for the Keyes Elegant Home group. We're preparing it for tomorrow's presentation to the client.</p><p>&nbsp;</p><p><strong>Corinne McCall (2:53 P.M.)</strong></p><p>Yes, I have just downloaded it. Is this about their new line of tableware?</p><p>&nbsp;</p><p><strong>Dennis Beck (2:54 P.M.)</strong></p><p>Yes. I'd like you to read it over.</p><p>&nbsp;</p><p><strong>Corinne McCall (3:01 P.M.)</strong></p><p>No problem. Would you like me to revise anything, or do you want me to just check that it is all clear?</p><p>&nbsp;</p><p><strong>Dennis Beck (3:02 P.M.)</strong></p><p>Feel free to add information to the section "Advertising Strategies," since that is your area of expertise.</p><p>&nbsp;</p><p><strong>Corinne McCall (3:03 P.M.)</strong></p><p>Will do. I'll get it back to you before the end of the day.</p>	1	2023-06-03 23:25:32.082188	2023-06-03 23:25:32.082188
76	95	<p><strong>To:</strong> Mara Renaldo<br><strong>From:</strong> Lisa Yang<br><strong>Date:</strong> May 28<br><strong>Subject: RE:</strong> Staffordsville Craft Fair</p><p>&nbsp;</p><p>Dear Ms. Renaldo,</p><p>&nbsp;</p><p>Thank you for your interest in selling your handcrafted items at the annual Staffordsville Craft Fair. Please note that all applicants must submit a $25 application fee, whether or not they want to share a space with another applicant. Moreover, all applicants must submit a minimum of four photographs of their work in order to be considered as a vendor. <strong>-[1]-.</strong></p><p>&nbsp;</p><p>In addition to photographs, we ask that you submit a rough a sketch showing how you would display your work. Since you propose to share a space with a friend, local potter Julia Berens, it would be helpful if your sketch could indicate how you are planning to use the space jointly. <strong>-[2]-.</strong></p><p>&nbsp;</p><p>Also, because we hold the fair rain or shine, all vendors must supply their own tenting to protect themselves and their wares from the possibility of rain. <strong>-[3]-.</strong></p><p>&nbsp;</p><p>Finally, please be aware that every year we receive far more applications from jewelry makers than we can accept. We hope that you will not be too discouraged if your work is not accepted this year, as you are applying for the first time. <strong>-[4]-</strong>.</p><p>&nbsp;</p><p>Thanks again, and best of luck with your application,</p><p><br>Lisa Yang</p>	1	2023-06-03 23:25:32.131545	2023-06-03 23:25:32.131545
90	103	<p><strong>From: </strong>Tanya Jefferson &lt;tjeff@keysuppliers.com&gt;</p><p><strong>To:</strong> info@danestongear.com</p><p><strong>Subject:</strong> Request for group rental information</p><p><strong>Date: </strong>May 29</p><p>&nbsp;</p><p>Hello Daneston Gear Company (DGC),<br>&nbsp;</p><p>I am the president of an activities club. This month. our 30 members intend to take a day trip to Daneston to go boating on the lake. Could you please send me information regarding your rates and offerings? We are most interested in renting boats that seat one person. Some time ago, I rented a kayak for myself from DGC, but this will be my first time renting from DGC for a group.</p><p>&nbsp;</p><p>Thank you,<br>&nbsp;</p><p>Tanya Jefferson</p>	1	2023-06-03 23:25:33.219084	2023-06-03 23:25:33.219084
77	96	<p><strong>SLEEP SOUNDLY SOLUTIONS</strong></p><p><i>Thank you for choosing Sleep Soundly Solutions!</i><br>&nbsp;</p><p>The updated control panel is linked to an integrated system that allows you to activate and disable all security systems in your home, including your Sleep Soundly motion sensor as well as your fire, smoke, and carbon monoxide detectors.&nbsp;<br>&nbsp;</p><p>All Sleep Soundly residential alarm systems have been tested thoroughly to ensure the highest quality and sensitivity, so you can sleep soundly in the knowledge that your home is protected. We have also developed a new smartphone application that will notify you of any disturbances wherever you are. The app is available for download now.<br>&nbsp;</p><p>Sleep Soundly control equipment is carefully manufactured for use with Sleep Soundly detectors and alarms. Using products manufactured by other companies may result in an alarm system that does not <i><strong>meet</strong></i> safety requirements for residential buildings or comply with local laws.</p>	1	2023-06-03 23:25:32.234403	2023-06-03 23:25:32.234403
78	97	<p>March 29</p><p>&nbsp;</p><p>Dr. Maritza Geerlings</p><p>Poseidonstraat 392</p><p>Paramaribo</p><p>Suriname</p><p>&nbsp;</p><p>Dear Dr. Geerlings,</p><p>&nbsp;</p><p>I am writing to thank you for your years of service on the faculty of the Jamaican Agricultural Training Academy (JATA) and to let you know about some exciting developments. As you know, JATA was originally <i><strong>established </strong></i>as a vocational school for agriculture but now offers courses in i varied array of disciplines, including cybersecurity, electrical engineering, and health information management. Our student body, which for the first ten years consisted almost exclusively of locals, is now culturally diverse, with students from across the Americas and Europe. Today's students work with sophisticated equipment, much of which did not exist in our early days.<br>&nbsp;</p><p>To reflect these and other significant changes that JATA has undergone over time, the Board of Trustees has approved a proposal by the Faculty Senate to rename the institution the Caribbean Academy of Science and Technology. As a result, a new institutional logo will be adopted. All students and faculty members, both current and former, are invited to participate in a logo design contest. Information about the contest will be forthcoming.<br>&nbsp;</p><p>The renaming ceremony and the introduction of the new logo will take place at 11 A.M. on 1 June, the twentieth anniversary of the institution. We hope you will be able to join us.<br>&nbsp;</p><p>Sincerely,<br>&nbsp;</p><p>Audley Bartlett<br>&nbsp;</p><p>Vice President for Academic Affairs,</p><p>Jamaican Agricultural Training Academy</p><p><br>&nbsp;</p>	1	2023-06-03 23:25:32.338599	2023-06-03 23:25:32.338599
79	98	<p><strong>Ashley Montaine 8:54 A.M.:</strong> How did the interview with Mr. Erickson go?</p><p>&nbsp;</p><p><strong>Dan Campbell 8:55 A.M.:</strong> I really enjoyed meeting him. I think he'd be a great reporter here. He seems smart and organized, and his samples show that he's a great writer.</p><p>&nbsp;</p><p><strong>Ashley Montaine 8:57 A.M.:</strong> Brooke, can you contact Mr. Erickson to set up the next interview? Is that a problem?<br>&nbsp;</p><p><strong>Dan Campbell 8:58 A.M.:</strong> I'd really like to work with him. It is very important that he impress Mr. Peters.<br>&nbsp;</p><p><strong>Brooke Randolph 8:59 A.M.: </strong>Not at all.<br>&nbsp;</p><p><strong>Ashley Montaine 9:00 A.M.: </strong>Thanks. I also see that he has a varied work history. That will make him a well-rounded reporter.<br>&nbsp;</p><p><strong>Brooke Randolph 9:02 A.M.:</strong> When would you like to meet with him again?<br>&nbsp;</p><p><strong>Dan Campbell 9:03 A.M.:</strong> Ashley, I believe you will participate in the next interview. Note that Mr. Peters is probably going to ask why Mr. Erickson wants to transition from freelance writing to in-house news reporting. Also, Mr. Peters will want assurances that he's committed and will stick around for several years.</p><p>&nbsp;</p><p><strong>Ashley Montaine 9:04 A.M.:</strong> Brooke, Mr. Peters and I are both free Friday morning.<br>&nbsp;</p><p><strong>Brooke Randolph 9:06 A.M.:</strong> Great. I'll write an e-mail shortly.</p>	1	2023-06-03 23:25:32.434348	2023-06-03 23:25:32.434348
80	99	<p><strong>Alberta Business Matters</strong></p><p>April issue</p><p>&nbsp;</p><h2><strong>Improve Your Office Environment Now!</strong></h2><p>Today's office environment, featuring numerous corridors, unexciting beige or white walls, and often rows of identical, windowless cubicles, might not inspire comfort, beauty, and energy. However, there are some easy, inexpensive ways to make your office space more inviting.<br>&nbsp;</p><p><strong>Air quality</strong></p><p>- Add some green plants to the décor. Plants offer a natural filtration system, increasing oxygen levels. Nonflowering plants should be preferred, as they will not scatter pollen.</p><p>- A small, tabletop air purifier helps improve stale air and removes dust.</p><p>&nbsp;</p><p><strong>Light quality</strong></p><p>- Take breaks and go outdoors. Even just five minutes before or after lunch break will provide your eyes with a respite from artificial light sources.</p><p>- Use desktop lamps with full-spectrum lightbulbs.</p><p>- Install double-glazed windows instead of blinds to reduce glare while maintaining natural light.</p><p>&nbsp;</p><p><strong>Stress relief</strong></p><p>- Earplugs or noise-cancelling headphones can block distracting noise in an open office floor plan.</p><p>- Photographs of loved ones and places we have visited for vacation are reminders of our life away from the office. Select a few favorite pictures as important decorative elements.</p><p>-------------------------</p><p><strong>Dear readers, if you have tips to add to this list, send them in and they will be published in next month's issue.</strong></p><p>-------------------------</p>	1	2023-06-03 23:25:32.534348	2023-06-03 23:25:32.534348
81	99	<p><strong>Alberta Business Matters</strong></p><p><strong>Letters to the Editor</strong></p><p>&nbsp;</p><p>It may interest your readers to know about the company I work for, called Moveable, Inc. We aspire to make dull offices more comfortable and convenient for workers, especially for today's on-the-move employees.</p><p>&nbsp;</p><p>For example, say you work two days a week at your headquarters in Edmonton, and the rest of the week you are in a satellite office. Our "Can-Do Case" ensures that your favorite office supplies always travel with you. Our "Modular Décor Kit," weighing just 1.75 kg, contains a portable reading lamp, a miniature silk plant, and a folding photo frame with space for four pictures. Look us up online and follow us on social media, as we offer new items frequently!</p><p>&nbsp;</p><p>Best,</p><p>Maria Testa</p><p><br>&nbsp;</p>	2	2023-06-03 23:25:32.635531	2023-06-03 23:25:32.635531
91	103	<p><strong>From:</strong> info@danestongear.com</p><p><strong>To:</strong> Tanya Jefferson &lt;tjeff@keysuppliers.com&gt;</p><p><strong>Subject:</strong> RE: Request for group rental information</p><p><strong>Date: </strong>May 30</p><p><strong>Attachment:&nbsp;</strong> Price list</p><p>&nbsp;</p><p>Dear Ms. Jefferson,<br>&nbsp;</p><p>Thank you for contacting us regarding your group's anticipated visit to DGC. We look forward to equipping your club for its next adventure. A price list is attached to this e-mail. If you wish to discuss our rentals in more detail, please call me at (888) 555-1578. Incidentally, we recently added a rowboat option that is an excellent choice for adults who wish to boat with their children.</p><p>&nbsp;</p><p>I will be pleased to help you when you are ready to make your reservation.<br>&nbsp;</p><p>Best,<br>&nbsp;</p><p>Adam Goldstein</p>	2	2023-06-03 23:25:33.262084	2023-06-03 23:25:33.262084
82	100	<p>http://www.Lloydtouringcompany.co.uk</p><p>&nbsp;</p><p>Choose one of Lloyd Touring Company's (LTC) most popular outings to see the best that London has to offer!&nbsp;</p><p><strong>Tour 1:</strong> Full-day tour of the most popular tourist sites on one of our famous red double-decker buses. See the Changing of the Guard and conclude the day with a river cruise.&nbsp;</p><p><strong>Tour 2: </strong>Full-day walking tour of London' best shopping areas. Explore London's famous department stores and wander along fashionable Bond and Oxford Streets.&nbsp;</p><p><strong>Tour 3:</strong> Half-day tour on a red double-decker bus, including private tour of the Tower of London and lunch at a nearby café.&nbsp;</p><p><strong>Tour 4:</strong> Half-day tour of Buckingham Palace, including the Changing of the Guard. Tour ends with a traditional fish-and-chips lunch.&nbsp;</p><p><strong>Tour 5:</strong> Full-day walking tour featuring London's top highlights. Complete the day with a medieval banquet.<br>&nbsp;</p><p>LTC's knowledgeable local staff members personally guide each one of our tours. Meals are not covered, except when noted in the tour description. Participants are responsible for meeting at chosen departure destination. LTC does not provide pickup from hotels. All tours can be upgraded for an additional fee to include an open-date ticket to the London Eye, London's famous observation wheel.</p>	1	2023-06-03 23:25:32.737883	2023-06-03 23:25:32.737883
83	100	<p><strong>--Ella Bouton</strong><br>&nbsp;</p><p>Lloyd Touring Company Review</p><p>&nbsp;</p><p>This was my first trip to London. I decided to see all the major tourist sites on my own, but I wanted someone to help me discover the most interesting places to shop in London. My LTC tour guide, Larissa, was wonderful. She is an avid shopper herself, and at the beginning of the tour, she tried to get to know the participants. She was able to guide everyone to the shops that they were most interested in. It was such a personalized tour! And it was a bonus that Larissa also speaks French. My daughter and I were visiting from Paris, and we appreciated being able to communicate in two languages. The tour was very reasonably priced, too. I would highly recommend it. The only unpleasant part of the tour was that Oxford Street was extremely crowded when we visited, and it was difficult to walk around easily.</p>	2	2023-06-03 23:25:32.834331	2023-06-03 23:25:32.834331
84	101	<p><strong>To:</strong> Joseph Morgan &lt;joseph.morgan@peltergraphics.com&gt;</p><p><strong>From:</strong> administrator@costaseminars.org</p><p><strong>Date:</strong> May 31</p><p><strong>Subject:</strong> Book order</p><p>&nbsp;</p><p>Dear Mr. Morgan,</p><p>&nbsp;</p><p>Thank you for registering for Emilio Costa's seminar on June 11 at the Rothford Business Center. We are glad you took advantage of the opportunity for conference participants to purchase some of Emilio Costa's graphic-design books at a discounted price. The information below is a confirmation of your order. The books will be waiting for you at the check-in desk on the day of the seminar. Please note that we will accept any major credit card for payment. We are looking forward to seeing you on June 11.</p><figure class="table"><table><tbody><tr><td><strong>Quantity</strong></td><td><strong>Title</strong></td><td><strong>Price</strong></td><td><strong>Discounted Price</strong></td><td><strong>Total Price</strong></td></tr><tr><td>1</td><td>Perfect Figures: Making Data Visually Appleaing</td><td>$22.00</td><td>$17.60</td><td>$17.60<br>&nbsp;</td></tr><tr><td>1</td><td>Logos in the Information Age</td><td>$18.00</td><td>$14.40</td><td>$14.40<br>&nbsp;</td></tr><tr><td>1</td><td>Branding Strategies in Graphic Design</td><td>$20.00</td><td>$16.00</td><td>$16.00<br>&nbsp;</td></tr><tr><td>2</td><td>Best Practices in Web Design: A Euroean Perspective</td><td>$28.00</td><td>$22.40</td><td>$44.80<br>&nbsp;</td></tr><tr><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td><strong>TOTAL DUE:</strong></td><td><strong>$92.80</strong></td></tr></tbody></table></figure>	1	2023-06-03 23:25:32.899075	2023-06-03 23:25:32.899075
85	101	<p><strong>Attention, Seminar Participants:</strong></p><p>Unfortunately, we do not have copies of Emilio Costa's book <i>Branding Strategies in Graphic Design</i> with us today. For those of you who have ordered it, please give your mailing address to the volunteer at the check-in desk, and the book will be mailed to your home at no cost to you. We will charge your credit card upon shipment. We are sorry for the inconvenience.</p>	2	2023-06-03 23:25:32.982081	2023-06-03 23:25:32.982081
86	101	<p><strong>*E-mail*</strong></p><p><strong>To: </strong>roberta.tsu@peltergraphics.com</p><p><strong>From:</strong> joseph.morgan@peltergraphics.com</p><p><strong>Date:</strong> June 22</p><p><strong>Sent: </strong>Costa book</p><p>&nbsp;</p><p>Dear Roberta,</p><p>&nbsp;</p><p>I'm looking forward to finishing up our brochure design for Entchen Financial Consultants. Before we submit our final draft, I would like to rethink how we are presenting our data. Have you had a chance to look through the Costa book I showed you? He gives great advice on improving the clarity of financial information in marketing materials. Anyway, let's talk about it at lunch tomorrow.</p><p>&nbsp;</p><p>Best,<br>&nbsp;</p><p>Joseph</p><p><br>&nbsp;</p>	3	2023-06-03 23:25:33.030966	2023-06-03 23:25:33.030966
87	102	<p><strong>Anton Building</strong></p><p>Clanton (12 October)--The planned renovation of the historic Anton Building by Jantuni Property Developers (JPD) is facing new delays. A JPD spokesperson says their negotiations with the city regarding a package of subsidies and tax incentives are ongoing and are proving somewhat contentious. According to the renovation plan, JPD must protect the historical integrity of the Anton Building while it creates a mixed-use interior, offering both office space and lower-level retail space. However, JPD's city permit to do the project is on hold pending the current negotiations.</p><p>This is making city revitalization advocates increasingly anxious. Aditi Yadav comments. "This plan to create useful space out of an empty decaying building will go a long way to restoring vibrancy to that area of the city. I sincerely hope that JPD does not back out. In creating their offer, the City Council should consider JPD's excellent record of beautifully restoring and maintaining several other historic buildings in Clanton."</p>	1	2023-06-03 23:25:33.08611	2023-06-03 23:25:33.08611
88	102	<p><strong>From:</strong> abautista@lenoiva-health.com</p><p><strong>To:</strong> t.rowell@jantunipropertydevelopers.com</p><p><strong>Date:</strong> 20 February</p><p><strong>Subject:</strong> Lease inquiry</p><p>&nbsp;</p><p>Dear Mr. Rowell,</p><p>&nbsp;</p><p>I am the owner of Lenoiva, a health-care technology company. We plan to expand our operations and we need new office space. The Anton Building is one of the locations in Clanton that we are considering. We have been informed that your restoration project of this building will be finished sometime this spring, which is good timing for us. We are particularly attracted by the easy access to public transportation services that your building offers. Do you still have spaces available for rent? We anticipate needing a space at least 300 square metres in size. Would there be any reserved parking for our employees if we rented there? We would appreciate any information you can provide.</p><p>&nbsp;</p><p>Thank you in advance,</p><p>&nbsp;</p><p><strong>Ana Bautista</strong></p><p><br>&nbsp;</p>	2	2023-06-03 23:25:33.132627	2023-06-03 23:25:33.132627
89	102	<figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1675264441/examify/image_tygie7.png"></figure>	3	2023-06-03 23:25:33.176374	2023-06-03 23:25:33.176374
92	103	<p><strong>DGC Price List</strong></p><figure class="table"><table><tbody><tr><td>&nbsp;</td><td>Boat type</td><td>Hourly rate<br>&nbsp;</td><td>Additional 1/2 hour<br>&nbsp;</td></tr><tr><td><strong>Option 1</strong><br>&nbsp;</td><td>2-person canoe<br>&nbsp;</td><td>$13<br>&nbsp;</td><td>$8<br>&nbsp;</td></tr><tr><td><strong>Option 2</strong><br>&nbsp;</td><td>3-person canoe<br>&nbsp;</td><td>$15<br>&nbsp;</td><td>$8</td></tr><tr><td><strong>Option 3</strong><br>&nbsp;</td><td>1-person kayak<br>&nbsp;</td><td>$11<br>&nbsp;</td><td>$8</td></tr><tr><td><strong>Option 4</strong><br>&nbsp;</td><td>2-person kayak<br>&nbsp;</td><td>$14<br>&nbsp;</td><td>$8<br>&nbsp;</td></tr><tr><td><strong>Option 5</strong><br>&nbsp;</td><td>3- or 4-person rowboat&nbsp;(3 adults&nbsp;or 2 adults and 2 children</td><td>$13<br>&nbsp;</td><td>$9<br>&nbsp;</td></tr></tbody></table></figure><p>- We are open every day from April to October, 10:00 A.M. to 6:30 P.M</p><p>- All boats must be returned by 6:15 P.M. on the day they are rented.</p><p>- Life jackets and paddles are included in the rental fee.</p><p>- Groups of ten or more qualify for a discount if they book at least one week in advance.</p>	3	2023-06-03 23:25:33.314343	2023-06-03 23:25:33.314343
\.


--
-- Data for Name: slide; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.slide (slide_id, sequence, lesson_id, text, created_at, updated_at) FROM stdin;
1	1	5	Poisoning by anticoagulants, assault, initial encounter	2023-06-03 15:05:03.642312	2023-06-03 15:05:03.642312
2	2	5	Poisoning by antipruritics, undetermined, initial encounter	2023-06-03 15:05:03.687355	2023-06-03 15:05:03.687355
3	3	5	Congenital malformation of musculoskeletal system, unspecified	2023-06-03 15:05:03.747979	2023-06-03 15:05:03.747979
4	4	5	Retained (old) magnetic foreign body in vitreous body, unspecified eye	2023-06-03 15:05:03.795983	2023-06-03 15:05:03.795983
5	5	5	Superficial frostbite of unspecified ear, subsequent encounter	2023-06-03 15:05:03.867628	2023-06-03 15:05:03.867628
6	6	5	Displaced fracture of distal phalanx of left lesser toe(s), subsequent encounter for fracture with routine healing	2023-06-03 15:05:03.909572	2023-06-03 15:05:03.909572
7	7	5	Osteomyelitis of right orbit	2023-06-03 15:05:03.951332	2023-06-03 15:05:03.951332
8	8	5	Poisoning by anthelminthics, undetermined, subsequent encounter	2023-06-03 15:05:04.011318	2023-06-03 15:05:04.011318
9	9	5	Presence of fully implantable artificial heart	2023-06-03 15:05:04.055661	2023-06-03 15:05:04.055661
10	10	5	Unspecified open wound of unspecified great toe with damage to nail, sequela	2023-06-03 15:05:04.105692	2023-06-03 15:05:04.105692
11	1	6	Corrosion of unspecified degree of right axilla, initial encounter	2023-06-03 15:05:04.153554	2023-06-03 15:05:04.153554
12	2	6	Puncture wound of lip and oral cavity with foreign body	2023-06-03 15:05:04.195488	2023-06-03 15:05:04.195488
13	3	6	Burn of first degree of single right finger (nail) except thumb, initial encounter	2023-06-03 15:05:04.23895	2023-06-03 15:05:04.23895
14	4	6	Asphyxiation due to smothering in furniture, accidental, subsequent encounter	2023-06-03 15:05:04.287203	2023-06-03 15:05:04.287203
15	5	6	Contusion and laceration of left cerebrum with loss of consciousness greater than 24 hours with return to pre-existing conscious level, initial encounter	2023-06-03 15:05:04.332743	2023-06-03 15:05:04.332743
16	6	6	Torus fracture of upper end of unspecified tibia, subsequent encounter for fracture with routine healing	2023-06-03 15:05:04.457162	2023-06-03 15:05:04.457162
17	7	6	Other juvenile arthritis, right ankle and foot	2023-06-03 15:05:04.497141	2023-06-03 15:05:04.497141
18	8	6	Displaced fracture of lunate [semilunar], left wrist, subsequent encounter for fracture with nonunion	2023-06-03 15:05:04.543386	2023-06-03 15:05:04.543386
19	9	6	Superficial foreign body, unspecified ankle, subsequent encounter	2023-06-03 15:05:04.586238	2023-06-03 15:05:04.586238
20	10	6	Pedestrian on foot injured in collision with roller-skater, subsequent encounter	2023-06-03 15:05:04.632328	2023-06-03 15:05:04.632328
21	1	8	Contusion of right eyelid and periocular area	2023-06-03 15:05:04.675187	2023-06-03 15:05:04.675187
22	2	8	Other specified fracture of unspecified pubis, subsequent encounter for fracture with delayed healing	2023-06-03 15:05:04.719218	2023-06-03 15:05:04.719218
23	3	8	Cerebral infarction due to unspecified occlusion or stenosis of unspecified cerebellar artery	2023-06-03 15:05:04.764754	2023-06-03 15:05:04.764754
24	4	8	Venous complication in pregnancy, unspecified, first trimester	2023-06-03 15:05:04.807239	2023-06-03 15:05:04.807239
25	5	8	Third [oculomotor] nerve palsy	2023-06-03 15:05:04.850404	2023-06-03 15:05:04.850404
26	6	8	Epidural hemorrhage with loss of consciousness of any duration with death due to other causes prior to regaining consciousness	2023-06-03 15:05:04.898846	2023-06-03 15:05:04.898846
27	7	8	Minor laceration of femoral artery, right leg, subsequent encounter	2023-06-03 15:05:04.939565	2023-06-03 15:05:04.939565
28	8	8	Generalized contraction of visual field, right eye	2023-06-03 15:05:04.982172	2023-06-03 15:05:04.982172
29	9	8	Dislocation of other internal joint prosthesis, sequela	2023-06-03 15:05:05.023626	2023-06-03 15:05:05.023626
30	10	8	Salter-Harris Type IV physeal fracture of upper end of radius, left arm, subsequent encounter for fracture with delayed healing	2023-06-03 15:05:05.071776	2023-06-03 15:05:05.071776
31	1	10	Unstable burst fracture of second lumbar vertebra, sequela	2023-06-03 15:05:05.118757	2023-06-03 15:05:05.118757
32	2	10	Diseases of the digestive system complicating pregnancy, unspecified trimester	2023-06-03 15:05:05.162794	2023-06-03 15:05:05.162794
33	3	10	Underdosing of other drug primarily affecting the autonomic nervous system, subsequent encounter	2023-06-03 15:05:05.206326	2023-06-03 15:05:05.206326
34	4	10	Anterior cerebral artery syndrome	2023-06-03 15:05:05.245805	2023-06-03 15:05:05.245805
35	5	10	Toxic effect of contact with venomous toad, undetermined, sequela	2023-06-03 15:05:05.293146	2023-06-03 15:05:05.293146
36	6	10	Chronic atticoantral suppurative otitis media, left ear	2023-06-03 15:05:05.381355	2023-06-03 15:05:05.381355
37	7	10	Other mastoiditis and related conditions, left ear	2023-06-03 15:05:05.59667	2023-06-03 15:05:05.59667
38	8	10	Tidal wave due to earthquake or volcanic eruption, subsequent encounter	2023-06-03 15:05:05.660475	2023-06-03 15:05:05.660475
39	9	10	Poisoning by histamine H2-receptor blockers, accidental (unintentional), sequela	2023-06-03 15:05:05.721373	2023-06-03 15:05:05.721373
40	10	10	Unspecified fracture of lower end of unspecified femur, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with delayed healing	2023-06-03 15:05:05.845228	2023-06-03 15:05:05.845228
41	1	14	Laceration of popliteal artery	2023-06-03 15:05:06.197422	2023-06-03 15:05:06.197422
42	2	14	Person on outside of car injured in collision with sport utility vehicle in nontraffic accident	2023-06-03 15:05:06.25356	2023-06-03 15:05:06.25356
43	3	14	Newborn affected by abnormality in fetal (intrauterine) heart rate or rhythm, unspecified as to time of onset	2023-06-03 15:05:06.303136	2023-06-03 15:05:06.303136
44	4	14	Drowning and submersion due to watercraft overturning	2023-06-03 15:05:06.357498	2023-06-03 15:05:06.357498
45	5	14	Accident to, on or involving ice yacht, subsequent encounter	2023-06-03 15:05:06.402794	2023-06-03 15:05:06.402794
46	6	14	Major osseous defect, unspecified lower leg	2023-06-03 15:05:06.4498	2023-06-03 15:05:06.4498
47	7	14	Laceration of blood vessel of right index finger, initial encounter	2023-06-03 15:05:06.517065	2023-06-03 15:05:06.517065
48	8	14	Unspecified motorcycle rider injured in collision with other motor vehicles in traffic accident, sequela	2023-06-03 15:05:06.562239	2023-06-03 15:05:06.562239
49	9	14	Poisoning by sulfonamides, accidental (unintentional), subsequent encounter	2023-06-03 15:05:06.609865	2023-06-03 15:05:06.609865
50	10	14	Stress fracture, right ankle, initial encounter for fracture	2023-06-03 15:05:06.652568	2023-06-03 15:05:06.652568
51	1	16	Other fracture of upper end of right radius, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	2023-06-03 15:05:06.701488	2023-06-03 15:05:06.701488
52	2	16	Pre-eclampsia	2023-06-03 15:05:06.745454	2023-06-03 15:05:06.745454
53	3	16	Accidental puncture and laceration of left eye and adnexa during an ophthalmic procedure	2023-06-03 15:05:06.795885	2023-06-03 15:05:06.795885
54	4	16	Encounter for fitting and adjustment of other specified devices	2023-06-03 15:05:06.844569	2023-06-03 15:05:06.844569
55	5	16	Coma scale, eyes open, to sound, 24 hours or more after hospital admission	2023-06-03 15:05:06.918238	2023-06-03 15:05:06.918238
56	6	16	Calculus of lower urinary tract	2023-06-03 15:05:06.967234	2023-06-03 15:05:06.967234
57	7	16	Anomalies of pupillary function	2023-06-03 15:05:07.026781	2023-06-03 15:05:07.026781
58	8	16	Pilonidal sinus with abscess	2023-06-03 15:05:07.075301	2023-06-03 15:05:07.075301
59	9	16	Maternal care for (suspected) fetal abnormality and damage, unspecified, fetus 1	2023-06-03 15:05:07.125855	2023-06-03 15:05:07.125855
60	10	16	Other fracture of head and neck of right femur, subsequent encounter for open fracture type I or II with delayed healing	2023-06-03 15:05:07.173068	2023-06-03 15:05:07.173068
61	1	21	Displaced associated transverse-posterior fracture of left acetabulum	2023-06-03 15:05:07.3081	2023-06-03 15:05:07.3081
62	2	21	Drug-induced chronic gout, unspecified knee, with tophus (tophi)	2023-06-03 15:05:07.353097	2023-06-03 15:05:07.353097
63	3	21	Arthropathies in other diseases classified elsewhere	2023-06-03 15:05:07.399417	2023-06-03 15:05:07.399417
64	4	21	Subluxation of interphalangeal joint of unspecified lesser toe(s), initial encounter	2023-06-03 15:05:07.444274	2023-06-03 15:05:07.444274
65	5	21	Unspecified nondisplaced fracture of sixth cervical vertebra, initial encounter for closed fracture	2023-06-03 15:05:07.487855	2023-06-03 15:05:07.487855
66	6	21	Exposure to tanning bed	2023-06-03 15:05:07.531505	2023-06-03 15:05:07.531505
67	7	21	Underdosing of ophthalmological drugs and preparations	2023-06-03 15:05:07.573269	2023-06-03 15:05:07.573269
68	8	21	Displaced apophyseal fracture of left femur, initial encounter for closed fracture	2023-06-03 15:05:07.619295	2023-06-03 15:05:07.619295
69	9	21	Toxic effect of metals	2023-06-03 15:05:07.666945	2023-06-03 15:05:07.666945
70	10	21	Other mechanical complication of carotid arterial graft (bypass)	2023-06-03 15:05:07.715112	2023-06-03 15:05:07.715112
71	1	22	Poisoning by unspecified drugs, medicaments and biological substances, assault, initial encounter	2023-06-03 15:05:07.762219	2023-06-03 15:05:07.762219
72	2	22	Nondisplaced intertrochanteric fracture of left femur, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with routine healing	2023-06-03 15:05:07.812446	2023-06-03 15:05:07.812446
73	3	22	Unspecified motorcycle rider injured in collision with other motor vehicles in traffic accident	2023-06-03 15:05:07.863043	2023-06-03 15:05:07.863043
74	4	22	Carcinoma in situ of rectosigmoid junction	2023-06-03 15:05:07.912581	2023-06-03 15:05:07.912581
75	5	22	Iridoschisis, unspecified eye	2023-06-03 15:05:07.961714	2023-06-03 15:05:07.961714
76	6	22	Nondisplaced fracture of coronoid process of right ulna, subsequent encounter for closed fracture with delayed healing	2023-06-03 15:05:08.002949	2023-06-03 15:05:08.002949
77	7	22	Other mechanical complication of prosthetic orbit of right eye, subsequent encounter	2023-06-03 15:05:08.048885	2023-06-03 15:05:08.048885
78	8	22	Nondisplaced oblique fracture of shaft of right fibula, subsequent encounter for open fracture type IIIA, IIIB, or IIIC with nonunion	2023-06-03 15:05:08.09078	2023-06-03 15:05:08.09078
79	9	22	Mild laceration of heart with hemopericardium, initial encounter	2023-06-03 15:05:08.139059	2023-06-03 15:05:08.139059
80	10	22	Pathological fracture, left fibula, subsequent encounter for fracture with malunion	2023-06-03 15:05:08.185594	2023-06-03 15:05:08.185594
81	1	23	Other contact with pig, initial encounter	2023-06-03 15:05:08.230492	2023-06-03 15:05:08.230492
82	2	23	Injury of pleura	2023-06-03 15:05:08.275058	2023-06-03 15:05:08.275058
83	3	23	Continuing pregnancy after intrauterine death of one fetus or more, first trimester, fetus 4	2023-06-03 15:05:08.318248	2023-06-03 15:05:08.318248
84	4	23	Subluxation of metacarpal (bone), proximal end of unspecified hand, initial encounter	2023-06-03 15:05:08.362811	2023-06-03 15:05:08.362811
85	5	23	Cervicalgia	2023-06-03 15:05:08.406233	2023-06-03 15:05:08.406233
86	6	23	Nondisplaced osteochondral fracture of right patella, subsequent encounter for closed fracture with routine healing	2023-06-03 15:05:08.450813	2023-06-03 15:05:08.450813
87	7	23	Other injury of rectum, subsequent encounter	2023-06-03 15:05:08.492823	2023-06-03 15:05:08.492823
88	8	23	Displaced fracture of greater trochanter of right femur, initial encounter for closed fracture	2023-06-03 15:05:08.53789	2023-06-03 15:05:08.53789
89	9	23	Injury of optic nerve, left eye, sequela	2023-06-03 15:05:08.591319	2023-06-03 15:05:08.591319
90	10	23	Other specified disorders of synovium and tendon, unspecified knee	2023-06-03 15:05:08.636372	2023-06-03 15:05:08.636372
91	1	28	Poisoning by aminoglycosides, intentional self-harm, sequela	2023-06-03 15:05:08.684569	2023-06-03 15:05:08.684569
92	2	28	Laceration of other blood vessels at hip and thigh level, unspecified leg	2023-06-03 15:05:08.731268	2023-06-03 15:05:08.731268
93	3	28	Unspecified car occupant injured in collision with fixed or stationary object in traffic accident	2023-06-03 15:05:08.777731	2023-06-03 15:05:08.777731
94	4	28	Nondisplaced spiral fracture of shaft of unspecified tibia, subsequent encounter for closed fracture with nonunion	2023-06-03 15:05:08.823468	2023-06-03 15:05:08.823468
95	5	28	War operations involving flamethrower, civilian, subsequent encounter	2023-06-03 15:05:08.885708	2023-06-03 15:05:08.885708
96	6	28	Nondisplaced fracture (avulsion) of lateral epicondyle of left humerus, initial encounter for open fracture	2023-06-03 15:05:08.931113	2023-06-03 15:05:08.931113
97	7	28	Struck by other hit or thrown ball, initial encounter	2023-06-03 15:05:08.978707	2023-06-03 15:05:08.978707
98	8	28	Secondary osteoarthritis, left ankle and foot	2023-06-03 15:05:09.018708	2023-06-03 15:05:09.018708
99	9	28	Person on outside of pick-up truck or van injured in noncollision transport accident in nontraffic accident, sequela	2023-06-03 15:05:09.062244	2023-06-03 15:05:09.062244
100	10	28	Unspecified physeal fracture of upper end of unspecified fibula	2023-06-03 15:05:09.113921	2023-06-03 15:05:09.113921
\.


--
-- Data for Name: unit; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.unit (unit_id, chapter_id, numeric_order, name, total_lesson, created_at, updated_at) FROM stdin;
21	1	2	Wrapsafe	0	2023-06-03 15:04:22.5344	2023-06-03 15:04:22.5344
22	2	2	Bytecard	0	2023-06-03 15:04:22.634331	2023-06-03 15:04:22.634331
23	3	2	Redhold	0	2023-06-03 15:04:22.734584	2023-06-03 15:04:22.734584
24	4	2	Prodder	0	2023-06-03 15:04:22.795622	2023-06-03 15:04:22.795622
25	5	2	Stringtough	0	2023-06-03 15:04:22.885735	2023-06-03 15:04:22.885735
26	6	2	Fintone	0	2023-06-03 15:04:22.984292	2023-06-03 15:04:22.984292
27	7	2	Konklux	0	2023-06-03 15:04:23.031163	2023-06-03 15:04:23.031163
28	8	2	Keylex	0	2023-06-03 15:04:23.071585	2023-06-03 15:04:23.071585
29	9	2	Overhold	0	2023-06-03 15:04:23.110658	2023-06-03 15:04:23.110658
30	10	2	Tresom	0	2023-06-03 15:04:23.152244	2023-06-03 15:04:23.152244
31	11	2	Trippledex	0	2023-06-03 15:04:23.214451	2023-06-03 15:04:23.214451
32	12	2	Flexidy	0	2023-06-03 15:04:23.256288	2023-06-03 15:04:23.256288
33	13	2	Transcof	0	2023-06-03 15:04:23.298615	2023-06-03 15:04:23.298615
34	14	2	Bitwolf	0	2023-06-03 15:04:23.342085	2023-06-03 15:04:23.342085
35	15	2	Fixflex	0	2023-06-03 15:04:23.394219	2023-06-03 15:04:23.394219
36	16	2	Temp	0	2023-06-03 15:04:23.438947	2023-06-03 15:04:23.438947
37	17	2	Sub-Ex	0	2023-06-03 15:04:23.484401	2023-06-03 15:04:23.484401
38	18	2	Mat Lam Tam	0	2023-06-03 15:04:23.526844	2023-06-03 15:04:23.526844
39	19	2	Redhold	0	2023-06-03 15:04:23.573075	2023-06-03 15:04:23.573075
40	20	2	Bigtax	0	2023-06-03 15:04:23.616679	2023-06-03 15:04:23.616679
41	1	3	Zathin	0	2023-06-03 15:04:23.66366	2023-06-03 15:04:23.66366
42	2	3	Solarbreeze	0	2023-06-03 15:04:23.755765	2023-06-03 15:04:23.755765
43	3	3	Cardguard	0	2023-06-03 15:04:24.126279	2023-06-03 15:04:24.126279
44	4	3	Sonair	0	2023-06-03 15:04:24.173058	2023-06-03 15:04:24.173058
45	5	3	Andalax	0	2023-06-03 15:04:24.220943	2023-06-03 15:04:24.220943
46	6	3	Lotstring	0	2023-06-03 15:04:24.267509	2023-06-03 15:04:24.267509
47	7	3	Trippledex	0	2023-06-03 15:04:24.317554	2023-06-03 15:04:24.317554
48	8	3	Redhold	0	2023-06-03 15:04:24.365881	2023-06-03 15:04:24.365881
49	9	3	Alphazap	0	2023-06-03 15:04:24.413577	2023-06-03 15:04:24.413577
50	10	3	Otcom	0	2023-06-03 15:04:24.45485	2023-06-03 15:04:24.45485
51	11	3	Keylex	0	2023-06-03 15:04:24.498411	2023-06-03 15:04:24.498411
52	12	3	Gembucket	0	2023-06-03 15:04:24.542756	2023-06-03 15:04:24.542756
53	13	3	Tres-Zap	0	2023-06-03 15:04:24.586229	2023-06-03 15:04:24.586229
54	14	3	Tempsoft	0	2023-06-03 15:04:24.634854	2023-06-03 15:04:24.634854
55	15	3	Stronghold	0	2023-06-03 15:04:24.696227	2023-06-03 15:04:24.696227
56	16	3	Lotlux	0	2023-06-03 15:04:24.746208	2023-06-03 15:04:24.746208
57	17	3	Vagram	0	2023-06-03 15:04:24.78796	2023-06-03 15:04:24.78796
58	18	3	Kanlam	0	2023-06-03 15:04:24.834852	2023-06-03 15:04:24.834852
59	19	3	Namfix	0	2023-06-03 15:04:24.879956	2023-06-03 15:04:24.879956
60	20	3	Lotstring	0	2023-06-03 15:04:24.931967	2023-06-03 15:04:24.931967
61	1	4	Zoolab	0	2023-06-03 15:04:24.976921	2023-06-03 15:04:24.976921
62	2	4	Duobam	0	2023-06-03 15:04:25.024338	2023-06-03 15:04:25.024338
63	3	4	Stim	0	2023-06-03 15:04:25.077077	2023-06-03 15:04:25.077077
64	4	4	Latlux	0	2023-06-03 15:04:25.122343	2023-06-03 15:04:25.122343
65	5	4	Zaam-Dox	0	2023-06-03 15:04:25.170181	2023-06-03 15:04:25.170181
66	6	4	Zontrax	0	2023-06-03 15:04:25.216022	2023-06-03 15:04:25.216022
67	7	4	Home Ing	0	2023-06-03 15:04:25.259688	2023-06-03 15:04:25.259688
68	8	4	Overhold	0	2023-06-03 15:04:25.301477	2023-06-03 15:04:25.301477
69	9	4	Zamit	0	2023-06-03 15:04:25.343869	2023-06-03 15:04:25.343869
70	10	4	It	0	2023-06-03 15:04:25.395201	2023-06-03 15:04:25.395201
71	11	4	Voltsillam	0	2023-06-03 15:04:25.454252	2023-06-03 15:04:25.454252
72	12	4	Rank	0	2023-06-03 15:04:25.496975	2023-06-03 15:04:25.496975
73	13	4	Andalax	0	2023-06-03 15:04:25.539175	2023-06-03 15:04:25.539175
74	14	4	Zoolab	0	2023-06-03 15:04:25.592757	2023-06-03 15:04:25.592757
75	15	4	Domainer	0	2023-06-03 15:04:25.637792	2023-06-03 15:04:25.637792
76	16	4	Transcof	0	2023-06-03 15:04:25.685436	2023-06-03 15:04:25.685436
77	17	4	Duobam	0	2023-06-03 15:04:25.74477	2023-06-03 15:04:25.74477
78	18	4	Duobam	0	2023-06-03 15:04:25.803845	2023-06-03 15:04:25.803845
79	19	4	Fixflex	0	2023-06-03 15:04:26.463254	2023-06-03 15:04:26.463254
80	20	4	Job	0	2023-06-03 15:04:26.515988	2023-06-03 15:04:26.515988
81	1	5	Temp	0	2023-06-03 15:04:26.565272	2023-06-03 15:04:26.565272
82	2	5	Span	0	2023-06-03 15:04:26.608472	2023-06-03 15:04:26.608472
83	3	5	Gembucket	0	2023-06-03 15:04:26.655524	2023-06-03 15:04:26.655524
84	4	5	Rank	0	2023-06-03 15:04:26.7045	2023-06-03 15:04:26.7045
85	5	5	Vagram	0	2023-06-03 15:04:26.751202	2023-06-03 15:04:26.751202
86	6	5	Stronghold	0	2023-06-03 15:04:26.802464	2023-06-03 15:04:26.802464
87	7	5	Tempsoft	0	2023-06-03 15:04:26.84644	2023-06-03 15:04:26.84644
88	8	5	Tres-Zap	0	2023-06-03 15:04:26.889992	2023-06-03 15:04:26.889992
89	9	5	Kanlam	0	2023-06-03 15:04:26.954262	2023-06-03 15:04:26.954262
90	10	5	Ronstring	0	2023-06-03 15:04:27.008294	2023-06-03 15:04:27.008294
91	11	5	Zoolab	0	2023-06-03 15:04:27.052954	2023-06-03 15:04:27.052954
92	12	5	Cardguard	0	2023-06-03 15:04:27.096187	2023-06-03 15:04:27.096187
93	13	5	Bamity	0	2023-06-03 15:04:27.387335	2023-06-03 15:04:27.387335
94	14	5	Y-find	0	2023-06-03 15:04:27.441229	2023-06-03 15:04:27.441229
95	15	5	Mat Lam Tam	0	2023-06-03 15:04:27.568904	2023-06-03 15:04:27.568904
96	16	5	Stringtough	0	2023-06-03 15:04:27.632574	2023-06-03 15:04:27.632574
97	17	5	Viva	0	2023-06-03 15:04:27.673487	2023-06-03 15:04:27.673487
98	18	5	Prodder	0	2023-06-03 15:04:27.73097	2023-06-03 15:04:27.73097
99	19	5	Subin	0	2023-06-03 15:04:27.79094	2023-06-03 15:04:27.79094
100	20	5	Lotlux	0	2023-06-03 15:04:27.844785	2023-06-03 15:04:27.844785
101	1	6	Tres-Zap	0	2023-06-03 15:04:27.893667	2023-06-03 15:04:27.893667
102	2	6	Hatity	0	2023-06-03 15:04:27.942969	2023-06-03 15:04:27.942969
103	3	6	It	0	2023-06-03 15:04:27.987808	2023-06-03 15:04:27.987808
104	4	6	Transcof	0	2023-06-03 15:04:28.030268	2023-06-03 15:04:28.030268
105	5	6	Stronghold	0	2023-06-03 15:04:28.08144	2023-06-03 15:04:28.08144
106	6	6	Tempsoft	0	2023-06-03 15:04:28.131021	2023-06-03 15:04:28.131021
107	7	6	Zathin	0	2023-06-03 15:04:28.184865	2023-06-03 15:04:28.184865
108	8	6	Quo Lux	0	2023-06-03 15:04:28.238943	2023-06-03 15:04:28.238943
109	9	6	Asoka	0	2023-06-03 15:04:28.286042	2023-06-03 15:04:28.286042
110	10	6	Quo Lux	0	2023-06-03 15:04:28.333342	2023-06-03 15:04:28.333342
111	11	6	Kanlam	0	2023-06-03 15:04:28.384336	2023-06-03 15:04:28.384336
112	12	6	Daltfresh	0	2023-06-03 15:04:28.429672	2023-06-03 15:04:28.429672
113	13	6	Fixflex	0	2023-06-03 15:04:28.472554	2023-06-03 15:04:28.472554
114	14	6	Holdlamis	0	2023-06-03 15:04:28.519044	2023-06-03 15:04:28.519044
115	15	6	Duobam	0	2023-06-03 15:04:28.562619	2023-06-03 15:04:28.562619
116	16	6	Rank	0	2023-06-03 15:04:28.612777	2023-06-03 15:04:28.612777
117	17	6	Tresom	0	2023-06-03 15:04:28.699259	2023-06-03 15:04:28.699259
118	18	6	Ronstring	0	2023-06-03 15:04:28.746853	2023-06-03 15:04:28.746853
17	17	1	Ronstring	15	2023-06-03 15:04:22.193105	2023-06-03 15:04:53.380648
18	18	1	It	15	2023-06-03 15:04:22.237955	2023-06-03 15:04:53.483266
19	19	1	Flexidy	15	2023-06-03 15:04:22.334334	2023-06-03 15:04:53.538957
20	20	1	Andalax	15	2023-06-03 15:04:22.434358	2023-06-03 15:04:53.581196
2	2	1	Bytecard	15	2023-06-03 15:04:20.979467	2023-06-03 15:04:52.050372
3	3	1	Bytecard	15	2023-06-03 15:04:21.050252	2023-06-03 15:04:52.236456
4	4	1	Y-find	15	2023-06-03 15:04:21.188124	2023-06-03 15:04:52.332628
5	5	1	Fixflex	15	2023-06-03 15:04:21.231651	2023-06-03 15:04:52.43497
6	6	1	Wrapsafe	15	2023-06-03 15:04:21.284009	2023-06-03 15:04:52.47707
7	7	1	Span	15	2023-06-03 15:04:21.334665	2023-06-03 15:04:52.52193
8	8	1	Latlux	15	2023-06-03 15:04:21.476824	2023-06-03 15:04:52.634601
9	9	1	Ronstring	15	2023-06-03 15:04:21.524474	2023-06-03 15:04:52.734321
10	10	1	Prodder	15	2023-06-03 15:04:21.580371	2023-06-03 15:04:52.78771
11	11	1	Bytecard	15	2023-06-03 15:04:21.629724	2023-06-03 15:04:52.886912
12	12	1	Tampflex	15	2023-06-03 15:04:21.734972	2023-06-03 15:04:52.931247
13	13	1	Overhold	15	2023-06-03 15:04:21.777135	2023-06-03 15:04:52.975419
15	15	1	Opela	15	2023-06-03 15:04:22.039027	2023-06-03 15:04:53.187157
16	16	1	Bitwolf	15	2023-06-03 15:04:22.128604	2023-06-03 15:04:53.334319
119	19	6	Tin	0	2023-06-03 15:04:28.797688	2023-06-03 15:04:28.797688
120	20	6	Namfix	0	2023-06-03 15:04:28.846758	2023-06-03 15:04:28.846758
121	1	7	Holdlamis	0	2023-06-03 15:04:28.899035	2023-06-03 15:04:28.899035
122	2	7	Y-Solowarm	0	2023-06-03 15:04:28.945047	2023-06-03 15:04:28.945047
123	3	7	Treeflex	0	2023-06-03 15:04:28.994814	2023-06-03 15:04:28.994814
124	4	7	Vagram	0	2023-06-03 15:04:29.070944	2023-06-03 15:04:29.070944
125	5	7	Temp	0	2023-06-03 15:04:29.213914	2023-06-03 15:04:29.213914
126	6	7	Lotlux	0	2023-06-03 15:04:29.261878	2023-06-03 15:04:29.261878
127	7	7	Span	0	2023-06-03 15:04:29.326258	2023-06-03 15:04:29.326258
128	8	7	Tampflex	0	2023-06-03 15:04:29.367027	2023-06-03 15:04:29.367027
129	9	7	Zamit	0	2023-06-03 15:04:29.411503	2023-06-03 15:04:29.411503
130	10	7	Fix San	0	2023-06-03 15:04:29.454962	2023-06-03 15:04:29.454962
131	11	7	Tin	0	2023-06-03 15:04:29.502473	2023-06-03 15:04:29.502473
132	12	7	Domainer	0	2023-06-03 15:04:29.547577	2023-06-03 15:04:29.547577
133	13	7	Ventosanzap	0	2023-06-03 15:04:29.592392	2023-06-03 15:04:29.592392
134	14	7	Subin	0	2023-06-03 15:04:29.63692	2023-06-03 15:04:29.63692
135	15	7	Bamity	0	2023-06-03 15:04:29.69351	2023-06-03 15:04:29.69351
136	16	7	Flowdesk	0	2023-06-03 15:04:29.74695	2023-06-03 15:04:29.74695
137	17	7	Ronstring	0	2023-06-03 15:04:29.790836	2023-06-03 15:04:29.790836
138	18	7	Kanlam	0	2023-06-03 15:04:29.847725	2023-06-03 15:04:29.847725
139	19	7	Viva	0	2023-06-03 15:04:29.893435	2023-06-03 15:04:29.893435
140	20	7	Alphazap	0	2023-06-03 15:04:29.939042	2023-06-03 15:04:29.939042
141	1	8	Namfix	0	2023-06-03 15:04:30.063035	2023-06-03 15:04:30.063035
142	2	8	Daltfresh	0	2023-06-03 15:04:30.11343	2023-06-03 15:04:30.11343
143	3	8	Opela	0	2023-06-03 15:04:30.171068	2023-06-03 15:04:30.171068
144	4	8	Bitwolf	0	2023-06-03 15:04:30.250947	2023-06-03 15:04:30.250947
145	5	8	Fintone	0	2023-06-03 15:04:30.300004	2023-06-03 15:04:30.300004
146	6	8	Zontrax	0	2023-06-03 15:04:30.345568	2023-06-03 15:04:30.345568
147	7	8	Zaam-Dox	0	2023-06-03 15:04:30.400201	2023-06-03 15:04:30.400201
148	8	8	Temp	0	2023-06-03 15:04:30.448843	2023-06-03 15:04:30.448843
149	9	8	Biodex	0	2023-06-03 15:04:30.491311	2023-06-03 15:04:30.491311
150	10	8	Fixflex	0	2023-06-03 15:04:30.550994	2023-06-03 15:04:30.550994
151	11	8	Stringtough	0	2023-06-03 15:04:30.615178	2023-06-03 15:04:30.615178
152	12	8	Tampflex	0	2023-06-03 15:04:30.659451	2023-06-03 15:04:30.659451
153	13	8	Ronstring	0	2023-06-03 15:04:30.734328	2023-06-03 15:04:30.734328
154	14	8	Tempsoft	0	2023-06-03 15:04:30.77974	2023-06-03 15:04:30.77974
155	15	8	Toughjoyfax	0	2023-06-03 15:04:30.843039	2023-06-03 15:04:30.843039
156	16	8	Cardguard	0	2023-06-03 15:04:30.937687	2023-06-03 15:04:30.937687
157	17	8	Bitchip	0	2023-06-03 15:04:31.034342	2023-06-03 15:04:31.034342
158	18	8	Redhold	0	2023-06-03 15:04:31.134348	2023-06-03 15:04:31.134348
159	19	8	Sonair	0	2023-06-03 15:04:31.177504	2023-06-03 15:04:31.177504
160	20	8	Alphazap	0	2023-06-03 15:04:31.219668	2023-06-03 15:04:31.219668
161	1	9	Cardguard	0	2023-06-03 15:04:31.281278	2023-06-03 15:04:31.281278
162	2	9	Mat Lam Tam	0	2023-06-03 15:04:31.326487	2023-06-03 15:04:31.326487
163	3	9	Subin	0	2023-06-03 15:04:31.434333	2023-06-03 15:04:31.434333
164	4	9	Fintone	0	2023-06-03 15:04:31.483452	2023-06-03 15:04:31.483452
165	5	9	Bigtax	0	2023-06-03 15:04:31.579443	2023-06-03 15:04:31.579443
166	6	9	Cookley	0	2023-06-03 15:04:31.680317	2023-06-03 15:04:31.680317
167	7	9	Namfix	0	2023-06-03 15:04:31.935022	2023-06-03 15:04:31.935022
168	8	9	Flexidy	0	2023-06-03 15:04:32.035921	2023-06-03 15:04:32.035921
169	9	9	Matsoft	0	2023-06-03 15:04:32.134326	2023-06-03 15:04:32.134326
170	10	9	Regrant	0	2023-06-03 15:04:32.234944	2023-06-03 15:04:32.234944
171	11	9	Regrant	0	2023-06-03 15:04:32.331254	2023-06-03 15:04:32.331254
172	12	9	Ventosanzap	0	2023-06-03 15:04:32.434957	2023-06-03 15:04:32.434957
173	13	9	Holdlamis	0	2023-06-03 15:04:32.534328	2023-06-03 15:04:32.534328
174	14	9	Domainer	0	2023-06-03 15:04:32.634343	2023-06-03 15:04:32.634343
175	15	9	Redhold	0	2023-06-03 15:04:32.73471	2023-06-03 15:04:32.73471
176	16	9	Overhold	0	2023-06-03 15:04:32.780245	2023-06-03 15:04:32.780245
177	17	9	Regrant	0	2023-06-03 15:04:32.83499	2023-06-03 15:04:32.83499
178	18	9	Vagram	0	2023-06-03 15:04:32.899596	2023-06-03 15:04:32.899596
179	19	9	Rank	0	2023-06-03 15:04:33.036067	2023-06-03 15:04:33.036067
180	20	9	Alphazap	0	2023-06-03 15:04:33.09083	2023-06-03 15:04:33.09083
181	1	10	Zaam-Dox	0	2023-06-03 15:04:33.189647	2023-06-03 15:04:33.189647
182	2	10	Bitwolf	0	2023-06-03 15:04:33.23897	2023-06-03 15:04:33.23897
183	3	10	Voltsillam	0	2023-06-03 15:04:33.289873	2023-06-03 15:04:33.289873
184	4	10	Biodex	0	2023-06-03 15:04:33.332599	2023-06-03 15:04:33.332599
185	5	10	Biodex	0	2023-06-03 15:04:33.412193	2023-06-03 15:04:33.412193
186	6	10	Solarbreeze	0	2023-06-03 15:04:33.459703	2023-06-03 15:04:33.459703
187	7	10	Domainer	0	2023-06-03 15:04:33.53919	2023-06-03 15:04:33.53919
188	8	10	Stronghold	0	2023-06-03 15:04:33.585815	2023-06-03 15:04:33.585815
189	9	10	Voltsillam	0	2023-06-03 15:04:33.62863	2023-06-03 15:04:33.62863
190	10	10	Zathin	0	2023-06-03 15:04:33.675922	2023-06-03 15:04:33.675922
191	11	10	Asoka	0	2023-06-03 15:04:33.721264	2023-06-03 15:04:33.721264
192	12	10	Konklux	0	2023-06-03 15:04:33.765617	2023-06-03 15:04:33.765617
193	13	10	Biodex	0	2023-06-03 15:04:33.810942	2023-06-03 15:04:33.810942
194	14	10	Zathin	0	2023-06-03 15:04:33.862294	2023-06-03 15:04:33.862294
195	15	10	Sonair	0	2023-06-03 15:04:33.909055	2023-06-03 15:04:33.909055
196	16	10	Duobam	0	2023-06-03 15:04:33.954249	2023-06-03 15:04:33.954249
197	17	10	Konklab	0	2023-06-03 15:04:33.996179	2023-06-03 15:04:33.996179
198	18	10	Wrapsafe	0	2023-06-03 15:04:34.038961	2023-06-03 15:04:34.038961
199	19	10	Regrant	0	2023-06-03 15:04:34.088922	2023-06-03 15:04:34.088922
200	20	10	Cookley	0	2023-06-03 15:04:34.130756	2023-06-03 15:04:34.130756
1	1	1	Sonair	15	2023-06-03 15:04:20.935008	2023-06-03 15:04:51.991525
14	14	1	Trippledex	15	2023-06-03 15:04:21.936866	2023-06-03 15:04:53.025894
\.


--
-- Data for Name: user_to_role; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.user_to_role (user_id, role_id, created_at, updated_at) FROM stdin;
1	1	2023-06-03 15:05:02.303472	2023-06-03 15:05:02.303472
2	4	2023-06-03 15:05:02.370587	2023-06-03 15:05:02.370587
3	4	2023-06-03 15:05:02.424556	2023-06-03 15:05:02.424556
4	4	2023-06-03 15:05:02.47907	2023-06-03 15:05:02.47907
5	4	2023-06-03 15:05:02.619152	2023-06-03 15:05:02.619152
6	4	2023-06-03 15:05:02.678976	2023-06-03 15:05:02.678976
7	4	2023-06-03 15:05:02.789367	2023-06-03 15:05:02.789367
8	4	2023-06-03 15:05:02.875348	2023-06-03 15:05:02.875348
9	4	2023-06-03 15:05:02.949493	2023-06-03 15:05:02.949493
10	4	2023-06-03 15:05:02.999417	2023-06-03 15:05:02.999417
11	4	2023-06-03 15:05:03.058956	2023-06-03 15:05:03.058956
12	4	2023-06-03 15:05:03.134972	2023-06-03 15:05:03.134972
13	4	2023-06-03 15:05:03.238976	2023-06-03 15:05:03.238976
14	4	2023-06-03 15:05:03.286207	2023-06-03 15:05:03.286207
15	4	2023-06-03 15:05:03.334962	2023-06-03 15:05:03.334962
16	4	2023-06-03 15:05:03.384991	2023-06-03 15:05:03.384991
17	4	2023-06-03 15:05:03.430237	2023-06-03 15:05:03.430237
18	4	2023-06-03 15:05:03.478189	2023-06-03 15:05:03.478189
19	4	2023-06-03 15:05:03.527891	2023-06-03 15:05:03.527891
20	4	2023-06-03 15:05:03.595202	2023-06-03 15:05:03.595202
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.users (user_id, mail, password, first_name, last_name, date_of_birth, phone_number, avt, banner, description, rank_id, accumulated_point, rank_point, refresh_token, created_at, updated_at) FROM stdin;
1	amaylin0@nature.com	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Arnoldo	Maylin	2010-05-05	1317232822	http://dummyimage.com/131x192.png/5fa2dd/ffffff	http://dummyimage.com/217x246.png/5fa2dd/ffffff	\N	1	0	0		2023-06-03 15:04:10.798982	2023-06-03 15:04:10.798982
2	growcastle1@opensource.org	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Gertrudis	Rowcastle	2009-07-22	6819408285	http://dummyimage.com/166x173.png/dddddd/000000	http://dummyimage.com/245x195.png/dddddd/000000	Pathological dislocation of left hip, not elsewhere classified	1	0	0		2023-06-03 15:04:10.867782	2023-06-03 15:04:10.867782
3	vmeikle2@buzzfeed.com	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Vito	Meikle	2014-07-20	3579866868	http://dummyimage.com/151x180.png/ff4444/ffffff	http://dummyimage.com/232x123.png/cc0000/ffffff	Open wound of larynx	1	0	0		2023-06-03 15:04:10.963648	2023-06-03 15:04:10.963648
4	bpiperley3@infoseek.co.jp	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Bethena	Piperley	2012-01-25	7478005811	http://dummyimage.com/187x171.png/cc0000/ffffff	http://dummyimage.com/209x150.png/ff4444/ffffff	Asphyxiation due to being trapped in a car trunk, accidental, sequela	1	0	0		2023-06-03 15:04:11.038615	2023-06-03 15:04:11.038615
5	rkenen4@census.gov	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Ronalda	Kenen	2005-09-12	4966681411	http://dummyimage.com/126x213.png/dddddd/000000	http://dummyimage.com/233x238.png/dddddd/000000	Other osteoporosis with current pathological fracture, unspecified shoulder, subsequent encounter for fracture with delayed healing	1	0	0		2023-06-03 15:04:11.1188	2023-06-03 15:04:11.1188
6	mglazzard5@meetup.com	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Maddie	Glazzard	2008-12-27	2968604340	http://dummyimage.com/249x223.png/5fa2dd/ffffff	http://dummyimage.com/155x151.png/ff4444/ffffff	Displaced comminuted fracture of shaft of humerus, right arm	1	0	0		2023-06-03 15:04:11.159311	2023-06-03 15:04:11.159311
7	igallard6@liveinternet.ru	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Idalia	Gallard	2006-01-16	1444726158	http://dummyimage.com/111x197.png/ff4444/ffffff	http://dummyimage.com/248x185.png/cc0000/ffffff	Unspecified car occupant injured in collision with two- or three-wheeled motor vehicle in nontraffic accident, subsequent encounter	1	0	0		2023-06-03 15:04:11.246997	2023-06-03 15:04:11.246997
8	shixson7@fda.gov	fJx96jVFs	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Hixson	2010-05-17	1694027569	http://dummyimage.com/139x116.png/5fa2dd/ffffff	http://dummyimage.com/213x117.png/dddddd/000000	Displaced Rolando's fracture, left hand, initial encounter for closed fracture	1	0	0		2023-06-03 15:04:11.312018	2023-06-03 15:04:11.312018
9	sbexley8@ycombinator.com	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Shoshanna	Bexley	2012-11-05	2541901703	http://dummyimage.com/115x111.png/cc0000/ffffff	http://dummyimage.com/155x159.png/ff4444/ffffff	Open bite of right shoulder, initial encounter	1	0	0		2023-06-03 15:04:11.438961	2023-06-03 15:04:11.438961
10	emcjury9@craigslist.org	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Enrica	McJury	2015-05-05	3659068398	http://dummyimage.com/176x188.png/cc0000/ffffff	http://dummyimage.com/247x183.png/cc0000/ffffff	Inflammation (infection) of postprocedural bleb, stage 2	1	0	0		2023-06-03 15:04:11.484503	2023-06-03 15:04:11.484503
11	bshrawleya@slideshare.net	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Brandy	Shrawley	2007-09-03	7905280047	http://dummyimage.com/101x110.png/ff4444/ffffff	http://dummyimage.com/119x185.png/dddddd/000000	Poisoning by enzymes, accidental (unintentional), sequela	1	0	0		2023-06-03 15:04:11.636406	2023-06-03 15:04:11.636406
12	cparisob@delicious.com	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Cami	Pariso	2004-08-29	1765284518	http://dummyimage.com/195x111.png/ff4444/ffffff	http://dummyimage.com/189x112.png/5fa2dd/ffffff	Malignant neoplasm of maxillary sinus	1	0	0		2023-06-03 15:04:11.737768	2023-06-03 15:04:11.737768
13	hpiertonc@theatlantic.com	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Herold	Pierton	2012-10-13	7925114095	http://dummyimage.com/196x209.png/dddddd/000000	http://dummyimage.com/224x199.png/ff4444/ffffff	Underdosing of antiallergic and antiemetic drugs	1	0	0		2023-06-03 15:04:11.836324	2023-06-03 15:04:11.836324
14	tvigerd@latimes.com	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Tuck	Viger	2010-07-03	3916663839	http://dummyimage.com/215x213.png/ff4444/ffffff	http://dummyimage.com/225x227.png/dddddd/000000	Burn of other parts of alimentary tract, sequela	1	0	0		2023-06-03 15:04:11.935878	2023-06-03 15:04:11.935878
15	cinde@opensource.org	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Court	Ind	2009-08-30	8553596457	http://dummyimage.com/209x209.png/cc0000/ffffff	http://dummyimage.com/193x217.png/cc0000/ffffff	Total perforations of tympanic membrane, left ear	1	0	0		2023-06-03 15:04:12.035033	2023-06-03 15:04:12.035033
16	jhunnicuttf@ustream.tv	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Jedd	Hunnicutt	2012-03-25	6355420285	http://dummyimage.com/173x164.png/dddddd/000000	http://dummyimage.com/161x235.png/ff4444/ffffff	Acute gastritis with bleeding	1	0	0		2023-06-03 15:04:12.13895	2023-06-03 15:04:12.13895
17	ciacomellig@shop-pro.jp	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Constantine	Iacomelli	2011-04-23	6383785537	http://dummyimage.com/163x177.png/cc0000/ffffff	http://dummyimage.com/151x117.png/5fa2dd/ffffff	Central perforation of tympanic membrane, right ear	1	0	0		2023-06-03 15:04:12.335162	2023-06-03 15:04:12.335162
18	jhaggerwoodh@360.cn	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Janette	Haggerwood	2011-07-09	1229230622	http://dummyimage.com/134x211.png/ff4444/ffffff	http://dummyimage.com/192x178.png/dddddd/000000	Nondisplaced fracture of fourth metatarsal bone, right foot, subsequent encounter for fracture with delayed healing	1	0	0		2023-06-03 15:04:12.393862	2023-06-03 15:04:12.393862
19	eashlini@dmoz.org	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Elsa	Ashlin	2008-09-08	2458908486	http://dummyimage.com/116x190.png/5fa2dd/ffffff	http://dummyimage.com/138x131.png/ff4444/ffffff	Toxic effect of arsenic and its compounds, assault, subsequent encounter	1	0	0		2023-06-03 15:04:12.466149	2023-06-03 15:04:12.466149
20	abc@gmail.com	$2b$10$6SQau4/ybhq8JPsuCciBmuVbIiuIzY0OC.IRWDickDeG0GF3Zs61.	Tate	Smullen	2008-03-12	3553500988	http://dummyimage.com/147x189.png/ff4444/ffffff	http://dummyimage.com/144x188.png/5fa2dd/ffffff	Displaced osteochondral fracture of right patella, subsequent encounter for open fracture type I or II with nonunion	1	0	0		2023-06-03 15:04:12.510771	2023-06-03 15:04:12.510771
21	hdatdragon2@gmail.com	$2b$10$M1qlGM8CVEqW3BKpCQ1IHeb2PNNcbYZkzjmaNhnfTAMSezsi.SILC	Hoang Dinh Anh 	Tuan	\N	\N	https://media.istockphoto.com/id/1223671392/vector/default-profile-picture-avatar-photo-placeholder-vector-illustration.jpg?s=170667a&w=0&k=20&c=m-F9Doa2ecNYEEjeplkFCmZBlc5tm1pl1F7cBCh9ZzM=	data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAX8AAACECAMAAABPuNs7AAAACVBMVEWAgICLi4uUlJSuV9pqAAABI0lEQVR4nO3QMQEAAAjAILV/aGPwjAjMbZybnTjbP9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b+1cxvnHi9hBAfkOyqGAAAAAElFTkSuQmCC	\N	1	0	0	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyIjp7ImlkIjoyMSwiZW1haWwiOiJoZGF0ZHJhZ29uMkBnbWFpbC5jb20iLCJmaXJzdE5hbWUiOiJIb2FuZyBEaW5oIEFuaCAiLCJsYXN0TmFtZSI6IlR1YW4iLCJyb2xlIjpudWxsfSwiaWF0IjoxNjg1ODM1OTM4LCJleHAiOjE3MTczOTM1Mzh9.sZCqFtvfqHS48EVMvu-b6Ss5-IRkxuotGwJcyaLyVqg	2023-06-03 15:12:07.045796	2023-06-03 23:45:38.524684
\.


--
-- Name: api_address_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_address_id_seq', 1, true);


--
-- Name: api_cartitem_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_cartitem_id_seq', 2, true);


--
-- Name: api_category_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_category_id_seq', 8, true);


--
-- Name: api_favoriteitem_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_favoriteitem_id_seq', 2, true);


--
-- Name: api_order_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_order_id_seq', 1, true);


--
-- Name: api_orderdetail_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_orderdetail_id_seq', 1, true);


--
-- Name: api_payment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_payment_id_seq', 1, true);


--
-- Name: api_paymentprovider_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_paymentprovider_id_seq', 6, true);


--
-- Name: api_product_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_product_id_seq', 49, true);


--
-- Name: api_review_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_review_id_seq', 1, false);


--
-- Name: api_usedvoucher_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_usedvoucher_id_seq', 1, false);


--
-- Name: api_variation_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_variation_id_seq', 174, true);


--
-- Name: api_voucher_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_voucher_id_seq', 1, false);


--
-- Name: auth_group_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.auth_group_id_seq', 1, false);


--
-- Name: auth_group_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.auth_group_permissions_id_seq', 1, false);


--
-- Name: auth_permission_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.auth_permission_id_seq', 76, true);


--
-- Name: authentication_user_groups_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.authentication_user_groups_id_seq', 1, false);


--
-- Name: authentication_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.authentication_user_id_seq', 4, true);


--
-- Name: authentication_user_user_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.authentication_user_user_permissions_id_seq', 1, false);


--
-- Name: chapter_chapter_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.chapter_chapter_id_seq', 100, true);


--
-- Name: choice_choice_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.choice_choice_id_seq', 775, true);


--
-- Name: comment_comment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.comment_comment_id_seq', 1, false);


--
-- Name: course_course_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.course_course_id_seq', 30, true);


--
-- Name: django_admin_log_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.django_admin_log_id_seq', 1, false);


--
-- Name: django_content_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.django_content_type_id_seq', 19, true);


--
-- Name: django_migrations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.django_migrations_id_seq', 65, true);


--
-- Name: exam_exam_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.exam_exam_id_seq', 12, true);


--
-- Name: exam_series_exam_series_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.exam_series_exam_series_id_seq', 2, true);


--
-- Name: exam_taking_exam_taking_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.exam_taking_exam_taking_id_seq', 1, true);


--
-- Name: flashcard_fc_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.flashcard_fc_id_seq', 200, true);


--
-- Name: flashcard_set_fc_set_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.flashcard_set_fc_set_id_seq', 20, true);


--
-- Name: flashcard_type_fc_type_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.flashcard_type_fc_type_id_seq', 3, true);


--
-- Name: hashtag_hashtag_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.hashtag_hashtag_id_seq', 61, true);


--
-- Name: lesson_lesson_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.lesson_lesson_id_seq', 300, true);


--
-- Name: note_note_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.note_note_id_seq', 50, true);


--
-- Name: part_part_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.part_part_id_seq', 7, true);


--
-- Name: question_question_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.question_question_id_seq', 200, true);


--
-- Name: rank_rank_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.rank_rank_id_seq', 9, true);


--
-- Name: roles_role_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.roles_role_id_seq', 1, false);


--
-- Name: set_question_set_question_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.set_question_set_question_id_seq', 103, true);


--
-- Name: side_side_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.side_side_id_seq', 92, true);


--
-- Name: slide_slide_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.slide_slide_id_seq', 100, true);


--
-- Name: unit_unit_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.unit_unit_id_seq', 200, true);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.users_user_id_seq', 21, true);


--
-- Name: answer_record answer_record_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.answer_record
    ADD CONSTRAINT answer_record_pkey PRIMARY KEY (exam_taking_id, question_id);


--
-- Name: api_address api_address_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_address
    ADD CONSTRAINT api_address_pkey PRIMARY KEY (id);


--
-- Name: api_cartitem api_cartitem_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_cartitem
    ADD CONSTRAINT api_cartitem_pkey PRIMARY KEY (id);


--
-- Name: api_category api_category_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_category
    ADD CONSTRAINT api_category_pkey PRIMARY KEY (id);


--
-- Name: api_favoriteitem api_favoriteitem_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_favoriteitem
    ADD CONSTRAINT api_favoriteitem_pkey PRIMARY KEY (id);


--
-- Name: api_order api_order_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_order
    ADD CONSTRAINT api_order_pkey PRIMARY KEY (id);


--
-- Name: api_orderdetail api_orderdetail_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_orderdetail
    ADD CONSTRAINT api_orderdetail_pkey PRIMARY KEY (id);


--
-- Name: api_payment api_payment_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_payment
    ADD CONSTRAINT api_payment_pkey PRIMARY KEY (id);


--
-- Name: api_paymentprovider api_paymentprovider_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_paymentprovider
    ADD CONSTRAINT api_paymentprovider_pkey PRIMARY KEY (id);


--
-- Name: api_product api_product_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_product
    ADD CONSTRAINT api_product_pkey PRIMARY KEY (id);


--
-- Name: api_review api_review_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_review
    ADD CONSTRAINT api_review_pkey PRIMARY KEY (id);


--
-- Name: api_usedvoucher api_usedvoucher_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_usedvoucher
    ADD CONSTRAINT api_usedvoucher_pkey PRIMARY KEY (id);


--
-- Name: api_variation api_variation_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_variation
    ADD CONSTRAINT api_variation_pkey PRIMARY KEY (id);


--
-- Name: api_voucher api_voucher_code_cd873620_uniq; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_voucher
    ADD CONSTRAINT api_voucher_code_cd873620_uniq UNIQUE (code);


--
-- Name: api_voucher api_voucher_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_voucher
    ADD CONSTRAINT api_voucher_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_name_key; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_name_key UNIQUE (name);


--
-- Name: auth_group_permissions auth_group_permissions_group_id_permission_id_0cd325b0_uniq; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_permission_id_0cd325b0_uniq UNIQUE (group_id, permission_id);


--
-- Name: auth_group_permissions auth_group_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_pkey PRIMARY KEY (id);


--
-- Name: auth_group auth_group_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.auth_group
    ADD CONSTRAINT auth_group_pkey PRIMARY KEY (id);


--
-- Name: auth_permission auth_permission_content_type_id_codename_01ab375a_uniq; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_codename_01ab375a_uniq UNIQUE (content_type_id, codename);


--
-- Name: auth_permission auth_permission_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_pkey PRIMARY KEY (id);


--
-- Name: authentication_user authentication_user_email_key; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.authentication_user
    ADD CONSTRAINT authentication_user_email_key UNIQUE (email);


--
-- Name: authentication_user_groups authentication_user_groups_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.authentication_user_groups
    ADD CONSTRAINT authentication_user_groups_pkey PRIMARY KEY (id);


--
-- Name: authentication_user_groups authentication_user_groups_user_id_group_id_8af031ac_uniq; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.authentication_user_groups
    ADD CONSTRAINT authentication_user_groups_user_id_group_id_8af031ac_uniq UNIQUE (user_id, group_id);


--
-- Name: authentication_user authentication_user_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.authentication_user
    ADD CONSTRAINT authentication_user_pkey PRIMARY KEY (id);


--
-- Name: authentication_user_user_permissions authentication_user_user_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.authentication_user_user_permissions
    ADD CONSTRAINT authentication_user_user_permissions_pkey PRIMARY KEY (id);


--
-- Name: authentication_user_user_permissions authentication_user_user_user_id_permission_id_ec51b09f_uniq; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.authentication_user_user_permissions
    ADD CONSTRAINT authentication_user_user_user_id_permission_id_ec51b09f_uniq UNIQUE (user_id, permission_id);


--
-- Name: chapter chapter_course_id_numeric_order_key; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.chapter
    ADD CONSTRAINT chapter_course_id_numeric_order_key UNIQUE (course_id, numeric_order);


--
-- Name: chapter chapter_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.chapter
    ADD CONSTRAINT chapter_pkey PRIMARY KEY (chapter_id);


--
-- Name: choice choice_order_choice_question_id_key; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.choice
    ADD CONSTRAINT choice_order_choice_question_id_key UNIQUE (order_choice, question_id);


--
-- Name: choice choice_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.choice
    ADD CONSTRAINT choice_pkey PRIMARY KEY (choice_id);


--
-- Name: comment comment_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_pkey PRIMARY KEY (comment_id);


--
-- Name: course course_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.course
    ADD CONSTRAINT course_pkey PRIMARY KEY (course_id);


--
-- Name: django_admin_log django_admin_log_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_pkey PRIMARY KEY (id);


--
-- Name: django_content_type django_content_type_app_label_model_76bd3d3b_uniq; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_app_label_model_76bd3d3b_uniq UNIQUE (app_label, model);


--
-- Name: django_content_type django_content_type_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.django_content_type
    ADD CONSTRAINT django_content_type_pkey PRIMARY KEY (id);


--
-- Name: django_migrations django_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.django_migrations
    ADD CONSTRAINT django_migrations_pkey PRIMARY KEY (id);


--
-- Name: django_session django_session_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.django_session
    ADD CONSTRAINT django_session_pkey PRIMARY KEY (session_key);


--
-- Name: exam exam_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.exam
    ADD CONSTRAINT exam_pkey PRIMARY KEY (exam_id);


--
-- Name: exam_series exam_series_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.exam_series
    ADD CONSTRAINT exam_series_pkey PRIMARY KEY (exam_series_id);


--
-- Name: exam_taking exam_taking_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.exam_taking
    ADD CONSTRAINT exam_taking_pkey PRIMARY KEY (exam_taking_id);


--
-- Name: flashcard flashcard_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard
    ADD CONSTRAINT flashcard_pkey PRIMARY KEY (fc_id);


--
-- Name: flashcard_set flashcard_set_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard_set
    ADD CONSTRAINT flashcard_set_pkey PRIMARY KEY (fc_set_id);


--
-- Name: flashcard_share_permit flashcard_share_permit_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard_share_permit
    ADD CONSTRAINT flashcard_share_permit_pkey PRIMARY KEY (user_id, fc_set_id);


--
-- Name: flashcard_type flashcard_type_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard_type
    ADD CONSTRAINT flashcard_type_pkey PRIMARY KEY (fc_type_id);


--
-- Name: hashtag hashtag_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.hashtag
    ADD CONSTRAINT hashtag_pkey PRIMARY KEY (hashtag_id);


--
-- Name: join_course join_course_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.join_course
    ADD CONSTRAINT join_course_pkey PRIMARY KEY (student_id, course_id);


--
-- Name: join_lesson join_lesson_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.join_lesson
    ADD CONSTRAINT join_lesson_pkey PRIMARY KEY (student_id, lesson_id);


--
-- Name: learnt_list learnt_list_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.learnt_list
    ADD CONSTRAINT learnt_list_pkey PRIMARY KEY (fc_id, user_id);


--
-- Name: lesson lesson_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.lesson
    ADD CONSTRAINT lesson_pkey PRIMARY KEY (lesson_id);


--
-- Name: lesson lesson_unit_id_numeric_order_key; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.lesson
    ADD CONSTRAINT lesson_unit_id_numeric_order_key UNIQUE (unit_id, numeric_order);


--
-- Name: like like_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public."like"
    ADD CONSTRAINT like_pkey PRIMARY KEY (user_id, comment_id);


--
-- Name: likes likes_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_pkey PRIMARY KEY (user_id, comment_id);


--
-- Name: note note_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.note
    ADD CONSTRAINT note_pkey PRIMARY KEY (note_id);


--
-- Name: part part_numeric_order_exam_id_key; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.part
    ADD CONSTRAINT part_numeric_order_exam_id_key UNIQUE (numeric_order, exam_id);


--
-- Name: part_option part_option_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.part_option
    ADD CONSTRAINT part_option_pkey PRIMARY KEY (exam_taking_id, part_id);


--
-- Name: part part_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.part
    ADD CONSTRAINT part_pkey PRIMARY KEY (part_id);


--
-- Name: question question_order_qn_set_question_id_key; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.question
    ADD CONSTRAINT question_order_qn_set_question_id_key UNIQUE (order_qn, set_question_id);


--
-- Name: question question_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.question
    ADD CONSTRAINT question_pkey PRIMARY KEY (question_id);


--
-- Name: rank rank_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.rank
    ADD CONSTRAINT rank_pkey PRIMARY KEY (rank_id);


--
-- Name: rating rating_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.rating
    ADD CONSTRAINT rating_pkey PRIMARY KEY (student_id, course_id);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (role_id);


--
-- Name: set_question set_question_part_id_numeric_order_key; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.set_question
    ADD CONSTRAINT set_question_part_id_numeric_order_key UNIQUE (part_id, numeric_order);


--
-- Name: set_question set_question_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.set_question
    ADD CONSTRAINT set_question_pkey PRIMARY KEY (set_question_id);


--
-- Name: side side_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.side
    ADD CONSTRAINT side_pkey PRIMARY KEY (side_id);


--
-- Name: side side_seq_set_question_id_key; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.side
    ADD CONSTRAINT side_seq_set_question_id_key UNIQUE (seq, set_question_id);


--
-- Name: slide slide_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.slide
    ADD CONSTRAINT slide_pkey PRIMARY KEY (slide_id);


--
-- Name: slide slide_sequence_lesson_id_key; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.slide
    ADD CONSTRAINT slide_sequence_lesson_id_key UNIQUE (sequence, lesson_id);


--
-- Name: unit unit_chapter_id_numeric_order_key; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_chapter_id_numeric_order_key UNIQUE (chapter_id, numeric_order);


--
-- Name: unit unit_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_pkey PRIMARY KEY (unit_id);


--
-- Name: user_to_role user_to_role_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.user_to_role
    ADD CONSTRAINT user_to_role_pkey PRIMARY KEY (user_id, role_id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (user_id);


--
-- Name: api_address_created_by_id_2ab20509; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_address_created_by_id_2ab20509 ON public.api_address USING btree (created_by_id);


--
-- Name: api_cartitem_created_by_id_722c65d0; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_cartitem_created_by_id_722c65d0 ON public.api_cartitem USING btree (created_by_id);


--
-- Name: api_cartitem_product_id_4699c5ae; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_cartitem_product_id_4699c5ae ON public.api_cartitem USING btree (product_id);


--
-- Name: api_cartitem_variation_id_542062f8; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_cartitem_variation_id_542062f8 ON public.api_cartitem USING btree (variation_id);


--
-- Name: api_favoriteitem_created_by_id_4e2d2705; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_favoriteitem_created_by_id_4e2d2705 ON public.api_favoriteitem USING btree (created_by_id);


--
-- Name: api_favoriteitem_product_id_69a6bf45; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_favoriteitem_product_id_69a6bf45 ON public.api_favoriteitem USING btree (product_id);


--
-- Name: api_order_created_by_id_408791c2; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_order_created_by_id_408791c2 ON public.api_order USING btree (created_by_id);


--
-- Name: api_order_voucher_id_d86e2daa; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_order_voucher_id_d86e2daa ON public.api_order USING btree (voucher_id);


--
-- Name: api_orderdetail_order_id_8651abdc; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_orderdetail_order_id_8651abdc ON public.api_orderdetail USING btree (order_id);


--
-- Name: api_orderdetail_product_id_1bc6f0ff; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_orderdetail_product_id_1bc6f0ff ON public.api_orderdetail USING btree (product_id);


--
-- Name: api_orderdetail_variation_id_def322b9; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_orderdetail_variation_id_def322b9 ON public.api_orderdetail USING btree (variation_id);


--
-- Name: api_payment_created_by_id_6e421157; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_payment_created_by_id_6e421157 ON public.api_payment USING btree (created_by_id);


--
-- Name: api_payment_provider_id_ffd2cdff; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_payment_provider_id_ffd2cdff ON public.api_payment USING btree (provider_id);


--
-- Name: api_product_category_id_a2b9d1e7; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_product_category_id_a2b9d1e7 ON public.api_product USING btree (category_id);


--
-- Name: api_review_created_by_id_48eceffb; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_review_created_by_id_48eceffb ON public.api_review USING btree (created_by_id);


--
-- Name: api_review_product_id_78d61c8d; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_review_product_id_78d61c8d ON public.api_review USING btree (product_id);


--
-- Name: api_review_variation_id_d75f4993; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_review_variation_id_d75f4993 ON public.api_review USING btree (variation_id);


--
-- Name: api_usedvoucher_user_id_715c010d; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_usedvoucher_user_id_715c010d ON public.api_usedvoucher USING btree (user_id);


--
-- Name: api_usedvoucher_voucher_id_5ab1808f; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_usedvoucher_voucher_id_5ab1808f ON public.api_usedvoucher USING btree (voucher_id);


--
-- Name: api_variation_product_id_e7532f50; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_variation_product_id_e7532f50 ON public.api_variation USING btree (product_id);


--
-- Name: api_voucher_code_cd873620_like; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX api_voucher_code_cd873620_like ON public.api_voucher USING btree (code varchar_pattern_ops);


--
-- Name: auth_group_name_a6ea08ec_like; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX auth_group_name_a6ea08ec_like ON public.auth_group USING btree (name varchar_pattern_ops);


--
-- Name: auth_group_permissions_group_id_b120cbf9; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX auth_group_permissions_group_id_b120cbf9 ON public.auth_group_permissions USING btree (group_id);


--
-- Name: auth_group_permissions_permission_id_84c5c92e; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX auth_group_permissions_permission_id_84c5c92e ON public.auth_group_permissions USING btree (permission_id);


--
-- Name: auth_permission_content_type_id_2f476e4b; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX auth_permission_content_type_id_2f476e4b ON public.auth_permission USING btree (content_type_id);


--
-- Name: authentication_user_email_2220eff5_like; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX authentication_user_email_2220eff5_like ON public.authentication_user USING btree (email varchar_pattern_ops);


--
-- Name: authentication_user_groups_group_id_6b5c44b7; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX authentication_user_groups_group_id_6b5c44b7 ON public.authentication_user_groups USING btree (group_id);


--
-- Name: authentication_user_groups_user_id_30868577; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX authentication_user_groups_user_id_30868577 ON public.authentication_user_groups USING btree (user_id);


--
-- Name: authentication_user_user_permissions_permission_id_ea6be19a; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX authentication_user_user_permissions_permission_id_ea6be19a ON public.authentication_user_user_permissions USING btree (permission_id);


--
-- Name: authentication_user_user_permissions_user_id_736ebf7e; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX authentication_user_user_permissions_user_id_736ebf7e ON public.authentication_user_user_permissions USING btree (user_id);


--
-- Name: django_admin_log_content_type_id_c4bce8eb; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX django_admin_log_content_type_id_c4bce8eb ON public.django_admin_log USING btree (content_type_id);


--
-- Name: django_admin_log_user_id_c564eba6; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX django_admin_log_user_id_c564eba6 ON public.django_admin_log USING btree (user_id);


--
-- Name: django_session_expire_date_a5c62663; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX django_session_expire_date_a5c62663 ON public.django_session USING btree (expire_date);


--
-- Name: django_session_session_key_c0390e0f_like; Type: INDEX; Schema: public; Owner: examify_pxac_user
--

CREATE INDEX django_session_session_key_c0390e0f_like ON public.django_session USING btree (session_key varchar_pattern_ops);


--
-- Name: users auto_create_user_to_role; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER auto_create_user_to_role AFTER INSERT ON public.users FOR EACH ROW EXECUTE FUNCTION public.fn_create_a_role_user();


--
-- Name: chapter auto_numeric_order_chapter; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER auto_numeric_order_chapter AFTER DELETE ON public.chapter FOR EACH ROW EXECUTE FUNCTION public.fn_update_numeric_order_chapter();


--
-- Name: lesson auto_numeric_order_lesson; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER auto_numeric_order_lesson AFTER DELETE ON public.lesson FOR EACH ROW EXECUTE FUNCTION public.fn_update_numeric_order_lesson();


--
-- Name: unit auto_numeric_order_unit; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER auto_numeric_order_unit AFTER DELETE ON public.unit FOR EACH ROW EXECUTE FUNCTION public.fn_update_numeric_order_unit();


--
-- Name: chapter create_chapter; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER create_chapter AFTER INSERT ON public.chapter FOR EACH ROW EXECUTE FUNCTION public.increase_total_chapter();


--
-- Name: lesson create_lesson_video; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER create_lesson_video AFTER INSERT ON public.lesson FOR EACH ROW EXECUTE FUNCTION public.increase_total_video_course();


--
-- Name: exam create_new_exam; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER create_new_exam AFTER INSERT ON public.exam FOR EACH ROW EXECUTE FUNCTION public.increase_total_exam();


--
-- Name: lesson create_new_lesson; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER create_new_lesson AFTER INSERT ON public.lesson FOR EACH ROW EXECUTE FUNCTION public.increase_total_lesson();


--
-- Name: rating create_rating_course; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER create_rating_course AFTER INSERT ON public.rating FOR EACH ROW EXECUTE FUNCTION public.fn_create_update_rating_course();


--
-- Name: chapter delete_chapter; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER delete_chapter AFTER DELETE ON public.chapter FOR EACH ROW EXECUTE FUNCTION public.decrease_total_chapter();


--
-- Name: exam delete_exam; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER delete_exam AFTER DELETE ON public.exam FOR EACH ROW EXECUTE FUNCTION public.decrease_total_exam();


--
-- Name: lesson delete_lesson; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER delete_lesson AFTER DELETE ON public.lesson FOR EACH ROW EXECUTE FUNCTION public.decrease_total_lesson();


--
-- Name: lesson delete_lesson_video; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER delete_lesson_video AFTER DELETE ON public.lesson FOR EACH ROW EXECUTE FUNCTION public.decrease_total_video_course();


--
-- Name: rating delete_rating_course; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER delete_rating_course AFTER DELETE ON public.rating FOR EACH ROW EXECUTE FUNCTION public.fn_delete_rating_course();


--
-- Name: part numeric_order_part_delete; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER numeric_order_part_delete AFTER DELETE ON public.part FOR EACH ROW EXECUTE FUNCTION public.fn_num_order_part_delete();


--
-- Name: part numeric_order_part_update; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER numeric_order_part_update AFTER UPDATE OF numeric_order ON public.part FOR EACH ROW WHEN ((pg_trigger_depth() = 0)) EXECUTE FUNCTION public.fn_num_order_part_update();


--
-- Name: question numeric_order_question_delete; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER numeric_order_question_delete AFTER DELETE ON public.question FOR EACH ROW EXECUTE FUNCTION public.fn_num_order_question_delete();


--
-- Name: set_question numeric_order_set_question_delete; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER numeric_order_set_question_delete AFTER DELETE ON public.set_question FOR EACH ROW EXECUTE FUNCTION public.fn_num_order_set_question_delete();


--
-- Name: set_question numeric_order_set_question_update; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER numeric_order_set_question_update AFTER UPDATE OF numeric_order ON public.set_question FOR EACH ROW WHEN ((pg_trigger_depth() = 0)) EXECUTE FUNCTION public.fn_num_order_set_question_update();


--
-- Name: side numeric_order_side_delete; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER numeric_order_side_delete AFTER DELETE ON public.side FOR EACH ROW EXECUTE FUNCTION public.fn_num_order_side_delete();


--
-- Name: side numeric_order_side_update; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER numeric_order_side_update AFTER UPDATE OF seq ON public.side FOR EACH ROW WHEN ((pg_trigger_depth() = 0)) EXECUTE FUNCTION public.fn_num_order_side_update();


--
-- Name: answer_record update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.answer_record FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: chapter update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.chapter FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: choice update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.choice FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: comment update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.comment FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: course update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.course FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: exam update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.exam FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: exam_series update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.exam_series FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: exam_taking update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.exam_taking FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: flashcard update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.flashcard FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: flashcard_set update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.flashcard_set FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: flashcard_type update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.flashcard_type FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: hashtag update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.hashtag FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: lesson update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.lesson FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: note update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.note FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: part update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.part FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: part_option update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.part_option FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: question update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.question FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: rank update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.rank FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: rating update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.rating FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: roles update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: set_question update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.set_question FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: side update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.side FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: slide update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.slide FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: unit update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.unit FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: user_to_role update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.user_to_role FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: users update_db_timestamp; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_db_timestamp BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.update_timestamp();


--
-- Name: part update_decrement_total_part_exam; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_decrement_total_part_exam AFTER DELETE ON public.part FOR EACH ROW EXECUTE FUNCTION public.fn_decrease_total_part_exam();


--
-- Name: question update_decrement_total_question_exam; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_decrement_total_question_exam AFTER DELETE ON public.question FOR EACH ROW EXECUTE FUNCTION public.fn_decrease_total_question_exam();


--
-- Name: question update_decrement_total_question_part; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_decrement_total_question_part AFTER DELETE ON public.question FOR EACH ROW EXECUTE FUNCTION public.fn_decrease_total_question_part();


--
-- Name: part update_increment_total_part_exam; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_increment_total_part_exam AFTER INSERT ON public.part FOR EACH ROW EXECUTE FUNCTION public.fn_increase_total_part_exam();


--
-- Name: question update_increment_total_question_exam; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_increment_total_question_exam AFTER INSERT ON public.question FOR EACH ROW EXECUTE FUNCTION public.fn_increase_total_question_exam();


--
-- Name: question update_increment_total_question_part; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_increment_total_question_part AFTER INSERT ON public.question FOR EACH ROW EXECUTE FUNCTION public.fn_increase_total_question_part();


--
-- Name: lesson update_lesson_unit_id; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_lesson_unit_id BEFORE UPDATE OF unit_id ON public.lesson FOR EACH ROW EXECUTE FUNCTION public.update_total_lesson();


--
-- Name: exam_taking update_nums_join_exam; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_nums_join_exam AFTER INSERT ON public.exam_taking FOR EACH ROW EXECUTE FUNCTION public.fn_increase_nums_join_exam();


--
-- Name: join_course update_participants_course; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_participants_course AFTER INSERT ON public.join_course FOR EACH ROW EXECUTE FUNCTION public.fn_increase_participants_course();


--
-- Name: rating update_rating_course; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_rating_course AFTER UPDATE OF rate ON public.rating FOR EACH ROW EXECUTE FUNCTION public.fn_create_update_rating_course();


--
-- Name: api_review update_reviews_stat_trigger; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_reviews_stat_trigger AFTER INSERT OR DELETE ON public.api_review FOR EACH ROW EXECUTE FUNCTION public.update_reviews_stat();


--
-- Name: flashcard_set update_sets_count_trigger; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_sets_count_trigger AFTER INSERT OR DELETE ON public.flashcard_set FOR EACH ROW EXECUTE FUNCTION public.update_sets_count();


--
-- Name: api_variation update_variations_count_trigger; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_variations_count_trigger AFTER INSERT OR DELETE ON public.api_variation FOR EACH ROW EXECUTE FUNCTION public.update_variations_count();


--
-- Name: lesson update_video_time_lesson; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_video_time_lesson AFTER UPDATE OF video_time ON public.lesson FOR EACH ROW EXECUTE FUNCTION public.update_total_video_course();


--
-- Name: flashcard update_words_count_trigger; Type: TRIGGER; Schema: public; Owner: examify_pxac_user
--

CREATE TRIGGER update_words_count_trigger AFTER INSERT OR DELETE ON public.flashcard FOR EACH ROW EXECUTE FUNCTION public.update_words_count();


--
-- Name: answer_record answer_record_choice_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.answer_record
    ADD CONSTRAINT answer_record_choice_id_fkey FOREIGN KEY (choice_id) REFERENCES public.choice(choice_id);


--
-- Name: answer_record answer_record_exam_taking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.answer_record
    ADD CONSTRAINT answer_record_exam_taking_id_fkey FOREIGN KEY (exam_taking_id) REFERENCES public.exam_taking(exam_taking_id);


--
-- Name: answer_record answer_record_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.answer_record
    ADD CONSTRAINT answer_record_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.question(question_id);


--
-- Name: api_address api_address_created_by_id_2ab20509_fk_authentication_user_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_address
    ADD CONSTRAINT api_address_created_by_id_2ab20509_fk_authentication_user_id FOREIGN KEY (created_by_id) REFERENCES public.authentication_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_cartitem api_cartitem_created_by_id_722c65d0_fk_authentication_user_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_cartitem
    ADD CONSTRAINT api_cartitem_created_by_id_722c65d0_fk_authentication_user_id FOREIGN KEY (created_by_id) REFERENCES public.authentication_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_cartitem api_cartitem_product_id_4699c5ae_fk_api_product_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_cartitem
    ADD CONSTRAINT api_cartitem_product_id_4699c5ae_fk_api_product_id FOREIGN KEY (product_id) REFERENCES public.api_product(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_cartitem api_cartitem_variation_id_542062f8_fk_api_variation_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_cartitem
    ADD CONSTRAINT api_cartitem_variation_id_542062f8_fk_api_variation_id FOREIGN KEY (variation_id) REFERENCES public.api_variation(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_favoriteitem api_favoriteitem_created_by_id_4e2d2705_fk_authentic; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_favoriteitem
    ADD CONSTRAINT api_favoriteitem_created_by_id_4e2d2705_fk_authentic FOREIGN KEY (created_by_id) REFERENCES public.authentication_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_favoriteitem api_favoriteitem_product_id_69a6bf45_fk_api_product_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_favoriteitem
    ADD CONSTRAINT api_favoriteitem_product_id_69a6bf45_fk_api_product_id FOREIGN KEY (product_id) REFERENCES public.api_product(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_order api_order_created_by_id_408791c2_fk_authentication_user_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_order
    ADD CONSTRAINT api_order_created_by_id_408791c2_fk_authentication_user_id FOREIGN KEY (created_by_id) REFERENCES public.authentication_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_order api_order_voucher_id_d86e2daa_fk_api_voucher_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_order
    ADD CONSTRAINT api_order_voucher_id_d86e2daa_fk_api_voucher_id FOREIGN KEY (voucher_id) REFERENCES public.api_voucher(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_orderdetail api_orderdetail_order_id_8651abdc_fk_api_order_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_orderdetail
    ADD CONSTRAINT api_orderdetail_order_id_8651abdc_fk_api_order_id FOREIGN KEY (order_id) REFERENCES public.api_order(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_orderdetail api_orderdetail_product_id_1bc6f0ff_fk_api_product_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_orderdetail
    ADD CONSTRAINT api_orderdetail_product_id_1bc6f0ff_fk_api_product_id FOREIGN KEY (product_id) REFERENCES public.api_product(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_orderdetail api_orderdetail_variation_id_def322b9_fk_api_variation_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_orderdetail
    ADD CONSTRAINT api_orderdetail_variation_id_def322b9_fk_api_variation_id FOREIGN KEY (variation_id) REFERENCES public.api_variation(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_payment api_payment_created_by_id_6e421157_fk_authentication_user_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_payment
    ADD CONSTRAINT api_payment_created_by_id_6e421157_fk_authentication_user_id FOREIGN KEY (created_by_id) REFERENCES public.authentication_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_payment api_payment_provider_id_ffd2cdff_fk_api_paymentprovider_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_payment
    ADD CONSTRAINT api_payment_provider_id_ffd2cdff_fk_api_paymentprovider_id FOREIGN KEY (provider_id) REFERENCES public.api_paymentprovider(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_product api_product_category_id_a2b9d1e7_fk_api_category_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_product
    ADD CONSTRAINT api_product_category_id_a2b9d1e7_fk_api_category_id FOREIGN KEY (category_id) REFERENCES public.api_category(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_review api_review_created_by_id_48eceffb_fk_authentication_user_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_review
    ADD CONSTRAINT api_review_created_by_id_48eceffb_fk_authentication_user_id FOREIGN KEY (created_by_id) REFERENCES public.authentication_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_review api_review_product_id_78d61c8d_fk_api_product_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_review
    ADD CONSTRAINT api_review_product_id_78d61c8d_fk_api_product_id FOREIGN KEY (product_id) REFERENCES public.api_product(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_review api_review_variation_id_d75f4993_fk_api_variation_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_review
    ADD CONSTRAINT api_review_variation_id_d75f4993_fk_api_variation_id FOREIGN KEY (variation_id) REFERENCES public.api_variation(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_usedvoucher api_usedvoucher_user_id_715c010d_fk_authentication_user_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_usedvoucher
    ADD CONSTRAINT api_usedvoucher_user_id_715c010d_fk_authentication_user_id FOREIGN KEY (user_id) REFERENCES public.authentication_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_usedvoucher api_usedvoucher_voucher_id_5ab1808f_fk_api_voucher_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_usedvoucher
    ADD CONSTRAINT api_usedvoucher_voucher_id_5ab1808f_fk_api_voucher_id FOREIGN KEY (voucher_id) REFERENCES public.api_voucher(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: api_variation api_variation_product_id_e7532f50_fk_api_product_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.api_variation
    ADD CONSTRAINT api_variation_product_id_e7532f50_fk_api_product_id FOREIGN KEY (product_id) REFERENCES public.api_product(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permissio_permission_id_84c5c92e_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissio_permission_id_84c5c92e_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_group_permissions auth_group_permissions_group_id_b120cbf9_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.auth_group_permissions
    ADD CONSTRAINT auth_group_permissions_group_id_b120cbf9_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: auth_permission auth_permission_content_type_id_2f476e4b_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.auth_permission
    ADD CONSTRAINT auth_permission_content_type_id_2f476e4b_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: authentication_user_user_permissions authentication_user__permission_id_ea6be19a_fk_auth_perm; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.authentication_user_user_permissions
    ADD CONSTRAINT authentication_user__permission_id_ea6be19a_fk_auth_perm FOREIGN KEY (permission_id) REFERENCES public.auth_permission(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: authentication_user_groups authentication_user__user_id_30868577_fk_authentic; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.authentication_user_groups
    ADD CONSTRAINT authentication_user__user_id_30868577_fk_authentic FOREIGN KEY (user_id) REFERENCES public.authentication_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: authentication_user_user_permissions authentication_user__user_id_736ebf7e_fk_authentic; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.authentication_user_user_permissions
    ADD CONSTRAINT authentication_user__user_id_736ebf7e_fk_authentic FOREIGN KEY (user_id) REFERENCES public.authentication_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: authentication_user_groups authentication_user_groups_group_id_6b5c44b7_fk_auth_group_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.authentication_user_groups
    ADD CONSTRAINT authentication_user_groups_group_id_6b5c44b7_fk_auth_group_id FOREIGN KEY (group_id) REFERENCES public.auth_group(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: chapter chapter_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.chapter
    ADD CONSTRAINT chapter_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.course(course_id);


--
-- Name: choice choice_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.choice
    ADD CONSTRAINT choice_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.question(question_id);


--
-- Name: comment comment_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.course(course_id);


--
-- Name: comment comment_respond_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_respond_id_fkey FOREIGN KEY (respond_id) REFERENCES public.comment(comment_id);


--
-- Name: comment comment_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.comment
    ADD CONSTRAINT comment_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(user_id);


--
-- Name: course course_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.course
    ADD CONSTRAINT course_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id);


--
-- Name: django_admin_log django_admin_log_content_type_id_c4bce8eb_fk_django_co; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_content_type_id_c4bce8eb_fk_django_co FOREIGN KEY (content_type_id) REFERENCES public.django_content_type(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: django_admin_log django_admin_log_user_id_c564eba6_fk_authentication_user_id; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.django_admin_log
    ADD CONSTRAINT django_admin_log_user_id_c564eba6_fk_authentication_user_id FOREIGN KEY (user_id) REFERENCES public.authentication_user(id) DEFERRABLE INITIALLY DEFERRED;


--
-- Name: exam exam_exam_series_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.exam
    ADD CONSTRAINT exam_exam_series_id_fkey FOREIGN KEY (exam_series_id) REFERENCES public.exam_series(exam_series_id) ON DELETE CASCADE;


--
-- Name: exam_series exam_series_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.exam_series
    ADD CONSTRAINT exam_series_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id);


--
-- Name: exam_taking exam_taking_exam_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.exam_taking
    ADD CONSTRAINT exam_taking_exam_id_fkey FOREIGN KEY (exam_id) REFERENCES public.exam(exam_id);


--
-- Name: exam_taking exam_taking_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.exam_taking
    ADD CONSTRAINT exam_taking_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: flashcard flashcard_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard
    ADD CONSTRAINT flashcard_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: flashcard flashcard_fc_set_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard
    ADD CONSTRAINT flashcard_fc_set_id_fkey FOREIGN KEY (fc_set_id) REFERENCES public.flashcard_set(fc_set_id) ON DELETE CASCADE;


--
-- Name: flashcard_set flashcard_set_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard_set
    ADD CONSTRAINT flashcard_set_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: flashcard_set flashcard_set_fc_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard_set
    ADD CONSTRAINT flashcard_set_fc_type_id_fkey FOREIGN KEY (fc_type_id) REFERENCES public.flashcard_type(fc_type_id) ON DELETE CASCADE;


--
-- Name: flashcard_share_permit flashcard_share_permit_fc_set_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard_share_permit
    ADD CONSTRAINT flashcard_share_permit_fc_set_id_fkey FOREIGN KEY (fc_set_id) REFERENCES public.flashcard_set(fc_set_id) ON DELETE CASCADE;


--
-- Name: flashcard_share_permit flashcard_share_permit_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.flashcard_share_permit
    ADD CONSTRAINT flashcard_share_permit_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: join_course join_course_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.join_course
    ADD CONSTRAINT join_course_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.course(course_id);


--
-- Name: join_course join_course_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.join_course
    ADD CONSTRAINT join_course_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(user_id);


--
-- Name: join_lesson join_lesson_lesson_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.join_lesson
    ADD CONSTRAINT join_lesson_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES public.lesson(lesson_id);


--
-- Name: join_lesson join_lesson_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.join_lesson
    ADD CONSTRAINT join_lesson_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(user_id);


--
-- Name: learnt_list learnt_list_fc_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.learnt_list
    ADD CONSTRAINT learnt_list_fc_id_fkey FOREIGN KEY (fc_id) REFERENCES public.flashcard(fc_id) ON DELETE CASCADE;


--
-- Name: learnt_list learnt_list_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.learnt_list
    ADD CONSTRAINT learnt_list_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON DELETE CASCADE;


--
-- Name: lesson lesson_unit_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.lesson
    ADD CONSTRAINT lesson_unit_id_fkey FOREIGN KEY (unit_id) REFERENCES public.unit(unit_id);


--
-- Name: like like_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public."like"
    ADD CONSTRAINT like_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comment(comment_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: like like_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public."like"
    ADD CONSTRAINT like_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- Name: likes likes_comment_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_comment_id_fkey FOREIGN KEY (comment_id) REFERENCES public.comment(comment_id);


--
-- Name: likes likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.likes
    ADD CONSTRAINT likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: note note_lesson_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.note
    ADD CONSTRAINT note_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES public.lesson(lesson_id);


--
-- Name: note note_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.note
    ADD CONSTRAINT note_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(user_id);


--
-- Name: part part_exam_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.part
    ADD CONSTRAINT part_exam_id_fkey FOREIGN KEY (exam_id) REFERENCES public.exam(exam_id);


--
-- Name: part_option part_option_exam_taking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.part_option
    ADD CONSTRAINT part_option_exam_taking_id_fkey FOREIGN KEY (exam_taking_id) REFERENCES public.exam_taking(exam_taking_id);


--
-- Name: part_option part_option_part_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.part_option
    ADD CONSTRAINT part_option_part_id_fkey FOREIGN KEY (part_id) REFERENCES public.part(part_id);


--
-- Name: question question_hashtag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.question
    ADD CONSTRAINT question_hashtag_id_fkey FOREIGN KEY (hashtag_id) REFERENCES public.hashtag(hashtag_id);


--
-- Name: question question_set_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.question
    ADD CONSTRAINT question_set_question_id_fkey FOREIGN KEY (set_question_id) REFERENCES public.set_question(set_question_id);


--
-- Name: rating rating_course_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.rating
    ADD CONSTRAINT rating_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.course(course_id);


--
-- Name: rating rating_student_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.rating
    ADD CONSTRAINT rating_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.users(user_id);


--
-- Name: set_question set_question_part_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.set_question
    ADD CONSTRAINT set_question_part_id_fkey FOREIGN KEY (part_id) REFERENCES public.part(part_id);


--
-- Name: side side_set_question_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.side
    ADD CONSTRAINT side_set_question_id_fkey FOREIGN KEY (set_question_id) REFERENCES public.set_question(set_question_id);


--
-- Name: slide slide_lesson_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.slide
    ADD CONSTRAINT slide_lesson_id_fkey FOREIGN KEY (lesson_id) REFERENCES public.lesson(lesson_id);


--
-- Name: unit unit_chapter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.unit
    ADD CONSTRAINT unit_chapter_id_fkey FOREIGN KEY (chapter_id) REFERENCES public.chapter(chapter_id);


--
-- Name: user_to_role user_to_role_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.user_to_role
    ADD CONSTRAINT user_to_role_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(role_id);


--
-- Name: user_to_role user_to_role_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.user_to_role
    ADD CONSTRAINT user_to_role_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(user_id);


--
-- Name: users users_rank_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: examify_pxac_user
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_rank_id_fkey FOREIGN KEY (rank_id) REFERENCES public.rank(rank_id);


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON SEQUENCES  TO examify_pxac_user;


--
-- Name: DEFAULT PRIVILEGES FOR TYPES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TYPES  TO examify_pxac_user;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON FUNCTIONS  TO examify_pxac_user;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: -; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT ALL ON TABLES  TO examify_pxac_user;


--
-- PostgreSQL database dump complete
--

