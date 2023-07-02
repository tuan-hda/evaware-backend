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
124	2023-07-01 09:21:10.083091+00	2023-07-01 09:21:10.083128+00	EKENÄSET	Armchair, Kilanda light beige	249.00	https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__1109687_pe870153_s5.jpg?f=s	2	0	f	0.0	2	0	Wood	77.00	30.00	Clean lines and supportive comfort, regardless if you’re reading, socializing with friends or just relaxing for a moment.	4.00	88.00
122	2023-07-01 09:20:33.273965+00	2023-07-01 09:20:33.273988+00	STRANDMON	Wing chair, Nordvalla dark gray	369.00	https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0325432_pe517964_s5.jpg?f=s	2	0	f	0.0	8	0	Polyester	45.00	40.00	You can really loosen up and relax in comfort because the high back on this chair provides extra support for your neck.	2.00	77.00
116	2023-07-01 09:15:42.253122+00	2023-07-01 09:15:42.253146+00	FRIHETEN	Sleeper sectional,3 seat w/storage, Skiftebo dark gray	899.00	https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0175610_pe328883_s5.jpg?f=s	1	0	f	0.0	5	0	Polyester	15.00	40.00	This sofa converts quickly and easily into a spacious bed when you remove the back cushions and pull out the underframe.	1.90	88.00
119	2023-07-01 09:16:22.541413+00	2023-07-01 09:16:22.541436+00	PÄRUP	Sofa, Vissle gray	499.00	https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__1041907_pe841187_s5.jpg?f=s	1	0	f	0.0	4	0	Polyester	15.00	40.00	Timeless design with delicate details such as piping around the armrests and wooden legs.	0.50	45.00
121	2023-07-01 09:16:48.517682+00	2023-07-01 09:16:48.517706+00	KIVIK	Sofa with chaise, Tibbleby beige/gray	1149.00	https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056147_pe848280_s5.jpg?f=s	1	0	f	0.0	5	0	Glass	15.00	40.00	Enjoy the super comfy KIVIK sofa with deep seat cushions made of pocket springs, high resilience foam and polyester fibers – adding both firm support and relaxing softness.	1.10	65.00
117	2023-07-01 09:15:58.311065+00	2023-07-01 09:15:58.311089+00	UPPLAND	Sofa, Blekinge white	849.00	https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0818565_pe774487_s5.jpg?f=s	1	0	f	0.0	7	0	Glass	88.00	80.00	Enjoy the super comfy UPPLAND sofa with embracing feel and deep seat cushions made of pocket springs, high resilience foam and polyester fibers, adding both firm support and relaxing softness.	4.00	90.00
125	2023-07-01 09:21:18.210406+00	2023-07-01 09:21:18.210428+00	NOLMYRA	Chair, birch veneer/gray	54.99	https://www.ikea.com/us/en/images/products/nolmyra-chair-birch-veneer-gray__0152020_pe310348_s5.jpg?f=s	2	0	f	0.0	2	0	Glass	29.00	88.00	The armchair is lightweight and easy to move if you want to clean the floor or rearrange the furniture.	1.10	77.00
118	2023-07-01 09:16:15.376664+00	2023-07-01 09:16:15.376688+00	GLOSTAD	Loveseat, Knisa dark gray	149.00	https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0950864_pe800736_s5.jpg?f=s	1	0	f	0.0	2	0	Wood	65.00	65.00	GLOSTAD sofa has a simple design which is also comfortable with its thick seat, padded armrests and soft back cushions that sit firmly in place.	1.20	29.00
120	2023-07-01 09:16:33.367058+00	2023-07-01 09:16:33.367085+00	HÄRLANDA	Sectional, 4-seat, with chaise/Inseros white	1649.00	https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-inseros-white__0747887_pe744745_s5.jpg?f=s	1	0	f	0.0	6	0	Polyester	120.00	75.00	HÄRLANDA sofa takes your comfort to a new level with deep pocket spring seat cushions, high resilience foam, and a top layer of polyester fibers that makes them soft to sink into.	0.90	50.00
130	2023-07-01 09:25:21.865528+00	2023-07-01 09:25:21.865566+00	MALM	6-drawer dresser, black-brown,	299.99	https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__0484881_pe621345_s5.jpg?f=s	3	0	f	0.0	4	0	Polyester	88.00	40.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	5.00	50.00
126	2023-07-01 09:21:25.649341+00	2023-07-01 09:21:25.649367+00	POÄNG	Armchair, birch veneer/Knisa light beige	129.00	https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0571500_pe666933_s5.jpg?f=s	2	0	f	0.0	7	0	Polyester	120.00	170.00	The layer-glued bent wood frame gives the armchair a comfortable resilience, making it perfect to relax in.	4.00	50.00
129	2023-07-01 09:25:11.942128+00	2023-07-01 09:25:11.942167+00	HEMNES	8-drawer dresser, white stain,	399.99	https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0627346_pe693299_s5.jpg?f=s	3	0	f	0.0	3	0	Fiberboard	120.00	40.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	2.00	29.00
123	2023-07-01 09:20:53.037097+00	2023-07-01 09:20:53.037121+00	POÄNG	Armchair, brown/Skiftebo dark gray	139.00	https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0937022_pe793528_s5.jpg?f=s	2	0	f	0.0	7	0	Fiberboard	65.00	30.00	Layer-glued bent oak gives comfortable resilience.	0.90	88.00
128	2023-07-01 09:24:59.99908+00	2023-07-01 09:24:59.999103+00	MALM	6-drawer dresser, white,	299.99	https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0484884_pe621348_s5.jpg?f=s	3	0	f	0.0	4	0	Wood	77.00	29.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	1.20	77.00
127	2023-07-01 09:21:43.147432+00	2023-07-01 09:21:43.147463+00	JÄTTEBO	Cover 1.5-seat module with storage, Tonerud gray	55.00	https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-tonerud-gray__1109576_pe870068_s5.jpg?f=s	2	0	f	0.0	3	0	Glass	88.00	65.00	This cover is made of Tonerud, a soft polyester fabric with a felt look and a two-toned melange effect.	1.90	65.00
131	2023-07-01 09:25:33.825817+00	2023-07-01 09:25:33.82585+00	KULLEN	6-drawer dresser, black-brown,	149.99	https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__0651638_pe706983_s5.jpg?f=s	3	0	f	0.0	2	0	Polyester	65.00	29.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	1.20	120.00
132	2023-07-01 09:25:40.683683+00	2023-07-01 09:25:40.683841+00	KOPPANG	6-drawer dresser, white,	259.99	https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__0651639_pe706984_s5.jpg?f=s	3	0	f	0.0	2	0	Polyester	77.00	170.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	0.50	50.00
133	2023-07-01 09:25:47.276718+00	2023-07-01 09:25:47.276753+00	MALM	4-drawer chest, white,	199.99	https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__0484879_pe621344_s5.jpg?f=s	3	0	f	0.0	4	0	Polyester	120.00	170.00	Of course your home should be a safe place for the entire family. That’s why hardware is included so that you can attach the chest of drawers to the wall.	0.50	15.00
138	2023-07-01 09:27:14.82709+00	2023-07-01 09:27:14.827113+00	BRIMNES	Bed frame with storage, white/Luröy,	399.00	https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__1151024_pe884762_s5.jpg?f=s	4	0	f	0.0	3	0	Polyester	50.00	80.00	Ample storage space is hidden neatly under the bed in 4 large drawers. Perfect for storing duvets, pillows and bed linen.	1.90	50.00
139	2023-07-01 09:27:23.79497+00	2023-07-01 09:27:23.795002+00	KLEPPSTAD	Bed frame, white/Vissle beige,	199.00	https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035340_pe840527_s5.jpg?f=s	4	0	f	0.0	1	0	Wood	29.00	65.00	The clean and simple design goes well with other bedroom furniture and fits perfectly in any modern bedroom.	2.00	45.00
134	2023-07-01 09:26:35.336254+00	2023-07-01 09:26:35.336287+00	MALM	Bed frame, high, black-brown/Luröy,	349.00	https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0638608_pe699032_s5.jpg?f=s	4	0	f	0.0	4	0	Fiberboard	50.00	65.00	Wood veneer gives you the same look, feel and beauty as solid wood with unique variations in grain, color and texture.	1.90	29.00
141	2023-07-01 09:28:01.745395+00	2023-07-01 09:28:01.745421+00	MICKE	Desk, white,	99.99	https://www.ikea.com/us/en/images/products/micke-desk-white__0736018_pe740345_s5.jpg?f=s	5	0	f	0.0	4	0	Glass	45.00	170.00	It’s easy to keep cords and cables out of sight but close at hand with the cable outlet at the back.	1.90	77.00
135	2023-07-01 09:26:47.077041+00	2023-07-01 09:26:47.077067+00	MALM	High bed frame/2 storage boxes, black-brown/Luröy,	449.00	https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__1154412_pe886059_s5.jpg?f=s	4	0	f	0.0	4	0	Polyester	15.00	65.00	Ample storage space is hidden neatly under the bed in 2 large drawers. Perfect for storing duvets, pillows and bed linen.	0.90	45.00
136	2023-07-01 09:26:58.236976+00	2023-07-01 09:26:58.237009+00	NEIDEN	Bed frame, pine,	59.00	https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__0749131_pe745500_s5.jpg?f=s	4	0	f	0.0	1	0	Glass	15.00	65.00	The compact design is perfect for tight spaces or under low ceilings, so you can make the most of your available space.	1.20	90.00
145	2023-07-01 09:28:58.733259+00	2023-07-01 09:28:58.733286+00	ALEX	Drawer unit, white,	110.00	https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0977775_pe813763_s5.jpg?f=s	5	0	f	0.0	3	0	Glass	77.00	29.00	Drawer stops prevent the drawer from being pulled out too far.	0.50	29.00
137	2023-07-01 09:27:03.485119+00	2023-07-01 09:27:03.485142+00	SAGSTUA	Bed frame, black/Luröy,	249.00	https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0662135_pe719104_s5.jpg?f=s	4	0	f	0.0	4	0	Glass	88.00	75.00	Brass-colored details on the headboard, footboard and legs give a unique twist to this classic design.	2.00	45.00
143	2023-07-01 09:28:30.741667+00	2023-07-01 09:28:30.741692+00	LAGKAPTEN	Tabletop, gray/turquoise,	59.99	https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207325_pe911159_s5.jpg?f=s	5	0	f	0.0	5	0	Fiberboard	45.00	75.00	The plywood-patterned edge band adds to the quality feel.	0.50	45.00
146	2023-07-01 09:29:34.405221+00	2023-07-01 09:29:34.405243+00	POÄNG	Armchair, birch veneer/Knisa light beige	129.00	https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0571500_pe666933_s5.jpg?f=s	6	0	f	0.0	7	0	Glass	29.00	65.00	The layer-glued bent wood frame gives the armchair a comfortable resilience, making it perfect to relax in.	4.00	77.00
140	2023-07-01 09:27:43.695092+00	2023-07-01 09:27:43.695129+00	LAGKAPTEN / ALEX	Desk, white anthracite/white,	279.99	https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184928_pe898140_s5.jpg?f=s	5	0	f	0.0	7	0	Polyester	45.00	30.00	The tabletop has pre-drilled holes to make it easier to attach to the underframe.	4.00	65.00
149	2023-07-01 09:30:08.270106+00	2023-07-01 09:30:08.270137+00	ADDE	Chair, white	20.00	https://www.ikea.com/us/en/images/products/adde-chair-white__0728280_pe736170_s5.jpg?f=s	6	0	f	0.0	2	0	Polyester	29.00	30.00	You can stack the chairs, so they take less space when you're not using them.	4.00	88.00
144	2023-07-01 09:28:44.267746+00	2023-07-01 09:28:44.26777+00	LINNMON / ADILS	Table, white,	54.99	https://www.ikea.com/us/en/images/products/linnmon-adils-table-white__0737165_pe740925_s5.jpg?f=s	5	0	f	0.0	4	0	Glass	50.00	88.00	Pre-drilled leg holes for easy assembly.	1.20	88.00
142	2023-07-01 09:28:13.489249+00	2023-07-01 09:28:13.489271+00	LAGKAPTEN / ALEX	Desk, white anthracite/white,	174.99	https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184966_pe898187_s5.jpg?f=s	5	0	f	0.0	7	0	Fiberboard	50.00	77.00	The tabletop has pre-drilled holes to make it easier to attach to the underframe.	15.00	50.00
148	2023-07-01 09:30:01.26215+00	2023-07-01 09:30:01.262174+00	ÖSTANÖ	Chair, red-brown Remmarn/red-brown	25.00	https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1120081_pe873713_s5.jpg?f=s	6	0	f	0.0	2	0	Wood	50.00	40.00	With sofa-comfort feel, this chair can also serve as cosy extra seating in your bedroom, hallway, living room or wherever you would like a comfy spot to relax without taking up too much space.	4.00	77.00
147	2023-07-01 09:29:52.137835+00	2023-07-01 09:29:52.137858+00	LIDÅS	Chair, black/Sefast black	55.00	https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167042_pe891344_s5.jpg?f=s	6	0	f	0.0	3	0	Wood	88.00	88.00	You decide the style of your chair. The seat shell is available in different colors, and the underframe SEFAST is available in white, black and chrome-plated colors.	1.10	88.00
152	2023-07-01 09:31:14.575865+00	2023-07-01 09:31:14.575898+00	KALLAX	Shelf unit, white,	89.99	https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__0644757_pe702939_s5.jpg?f=s	7	0	f	0.0	5	0	Polyester	120.00	88.00	The simple design with clean lines makes KALLAX flexible and easy to use at home.	5.00	29.00
150	2023-07-01 09:30:16.178121+00	2023-07-01 09:30:16.178217+00	GUNDE	Folding chair, white	12.99	https://www.ikea.com/us/en/images/products/gunde-folding-chair-white__0728314_pe736185_s5.jpg?f=s	6	0	f	0.0	2	0	Fiberboard	120.00	88.00	You can fold the chair, so it takes less space when you're not using it.	15.00	50.00
154	2023-07-01 09:31:39.501772+00	2023-07-01 09:31:39.501795+00	BILLY	Bookcase, white,	49.00	https://www.ikea.com/us/en/images/products/billy-bookcase-white__0644260_pe702536_s5.jpg?f=s	7	0	f	0.0	3	0	Wood	45.00	80.00	Narrow shelves help you use small wall spaces effectively by accommodating small items in a minimum of space.	1.10	77.00
151	2023-07-01 09:30:22.971069+00	2023-07-01 09:30:22.971107+00	TEODORES	Chair, white	45.00	https://www.ikea.com/us/en/images/products/teodores-chair-white__0727344_pe735616_s5.jpg?f=s	6	0	f	0.0	4	0	Fiberboard	90.00	88.00	The chair is easy to store when not in use, since you can stack up to 6 chairs on top of each other.	1.20	90.00
153	2023-07-01 09:31:28.441379+00	2023-07-01 09:31:28.441409+00	KALLAX	Shelf unit with 4 inserts, white,	169.99	https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__0754627_pe747994_s5.jpg?f=s	7	0	f	0.0	4	0	Polyester	50.00	170.00	A simple unit can be enough storage for a limited space or the foundation for a larger storage solution if your needs change.	0.50	45.00
155	2023-07-01 09:31:49.778266+00	2023-07-01 09:31:49.778291+00	BAGGEBO	Shelf unit, metal/white,	24.99	https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__0981562_pe815396_s5.jpg?f=s	7	0	f	0.0	1	0	Glass	77.00	29.00	The metal frame and mesh shelves make a nice and practical place for your books, decorations and other things that you like.	0.50	50.00
156	2023-07-01 09:31:55.002979+00	2023-07-01 09:31:55.003003+00	BILLY	Bookcase with glass doors, dark blue,	229.00	https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-dark-blue__0429309_pe584188_s5.jpg?f=s	7	0	f	0.0	2	0	Polyester	29.00	170.00	Glass-door cabinet keeps your favorite items free from dust but still visible.	2.00	45.00
162	2023-07-01 09:32:52.749003+00	2023-07-01 09:32:52.749028+00	LANEBERG / STEFAN	Table and 4 chairs, brown/brown-black,	389.00	https://www.ikea.com/us/en/images/products/laneberg-stefan-table-and-4-chairs-brown-brown-black__1097706_pe865092_s5.jpg?f=s	8	0	f	0.0	2	0	Polyester	29.00	77.00	The dining table will bring a sense of nature to your dining space. The tones of a rustic white finish let the beauty of the wood grains shine.	15.00	29.00
157	2023-07-01 09:32:02.841363+00	2023-07-01 09:32:02.841398+00	LACK	Wall shelf unit, white,	99.99	https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white__0246565_pe385541_s5.jpg?f=s	7	0	f	0.0	3	0	Glass	50.00	77.00	Shallow shelves help you to use the walls in your home efficiently. They hold a lot of things without taking up much space in the room.	5.00	90.00
158	2023-07-01 09:32:28.537415+00	2023-07-01 09:32:28.537439+00	JOKKMOKK	Table and 4 chairs, antique stain	249.99	https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-antique-stain__0736929_pe740809_s5.jpg?f=s	8	0	f	0.0	2	0	Polyester	120.00	65.00	Easy to bring home since the whole dining set is packed in one box.	1.20	88.00
163	2023-07-01 09:32:59.902546+00	2023-07-01 09:32:59.90257+00	MÖRBYLÅNGA / LILLÅNÄS	Table and 6 chairs, oak veneer brown stained/chrome plated Gunnared beige,	1689.00	https://www.ikea.com/us/en/images/products/moerbylanga-lillanaes-table-and-6-chairs-oak-veneer-brown-stained-chrome-plated-gunnared-beige__1150421_pe884533_s5.jpg?f=s	8	0	f	0.0	1	0	Fiberboard	50.00	77.00	Oak is an exceedingly strong and durable hardwood with a prominent grain. It darkens beautifully with age acquiring a golden-brown undertone.	4.00	29.00
159	2023-07-01 09:32:36.373617+00	2023-07-01 09:32:36.37364+00	DOCKSTA	Table, white/white,	279.99	https://www.ikea.com/us/en/images/products/docksta-table-white-white__0803262_pe768820_s5.jpg?f=s	8	0	f	0.0	2	0	Fiberboard	15.00	170.00	We have tested it for you! The table’s surface is resistant to liquids, food stains, oil, heat, scratches and bumps, while its construction is stable, strong and durable to withstand years of daily use.	1.10	77.00
160	2023-07-01 09:32:43.064338+00	2023-07-01 09:32:43.064364+00	SKOGSTA / NORDVIKEN	Table and 6 chairs, acacia/black,	999.00	https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__1097254_pe864851_s5.jpg?f=s	8	0	f	0.0	1	0	Fiberboard	77.00	40.00	Every table is unique, with varying grain pattern and natural color shifts that are part of the charm of wood.	1.10	88.00
161	2023-07-01 09:32:47.71016+00	2023-07-01 09:32:47.710184+00	SKOGSTA	Dining table, acacia,	549.00	https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0546603_pe656255_s5.jpg?f=s	8	0	f	0.0	1	0	Wood	15.00	170.00	Acacia has a rich brown color and distinctive grain pattern. It is highly durable, resistant to scratches and water, ideal for heavy-use. Acacia slightly darkens with age.	2.00	65.00
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
374	2023-07-01 09:15:52.554807+00	2023-07-01 09:15:52.55483+00	20	dark gray	{https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0175610_pe328883_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0779005_ph163058_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__1089881_pe861727_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0779007_ph163064_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0779006_ph163062_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0833845_pe603738_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-dark-gray__0833847_pe604692_s5.jpg?f=s}	116	f
375	2023-07-01 09:15:53.267203+00	2023-07-01 09:15:53.267227+00	20	black	{https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0248337_pe386785_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0727225_pe735670_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0829726_pe600308_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0732486_pe738637_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0829731_pe603749_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0829730_pe602871_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-bomstad-black__0829733_pe604690_s5.jpg?f=s}	116	f
376	2023-07-01 09:15:53.69747+00	2023-07-01 09:15:53.697494+00	20	beige	{https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0690253_pe723174_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0690251_pe723175_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__1184604_ph179194_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0690249_pe723173_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0690250_pe723177_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0690247_pe723171_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-beige__0787554_pe763281_s5.jpg?f=s}	116	f
377	2023-07-01 09:15:54.039439+00	2023-07-01 09:15:54.039465+00	20	dark gray	{https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690261_pe723182_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690259_pe723183_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690260_pe723184_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__1089879_pe861725_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690257_pe723181_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690258_pe723180_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-hyllie-dark-gray__0690255_pe723178_s5.jpg?f=s}	116	f
378	2023-07-01 09:15:54.472664+00	2023-07-01 09:15:54.472687+00	20	blue	{https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690243_pe723167_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690241_pe723168_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__1089880_pe861726_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690242_pe723169_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690238_pe723165_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690239_pe723166_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/friheten-sleeper-sectional-3-seat-w-storage-skiftebo-blue__0690240_pe723170_s5.jpg?f=s}	116	f
379	2023-07-01 09:16:08.773386+00	2023-07-01 09:16:08.77342+00	20	white	{https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0818565_pe774487_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0818564_pe774486_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0818534_pe774464_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0261000_pe404970_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0739096_pe225167_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0934662_pe792483_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0937793_pe793848_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-blekinge-white__0252533_pe391799_s5.jpg?f=s}	117	f
380	2023-07-01 09:16:09.285354+00	2023-07-01 09:16:09.285393+00	20	beige	{https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0818569_pe774497_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0818568_pe774490_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0818541_pe774472_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0929127_pe790146_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0934663_pe792484_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0937794_pe793849_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-beige__0928381_pe789853_s5.jpg?f=s}	117	f
381	2023-07-01 09:16:09.637365+00	2023-07-01 09:16:09.637389+00	20	gray	{https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0818567_pe774489_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0818566_pe774488_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0818537_pe774468_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0929128_pe790147_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0939196_pe794479_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0934664_pe792485_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0818497_pe774439_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-hallarp-gray__0948958_pe799429_s5.jpg?f=s}	117	f
382	2023-07-01 09:16:10.025453+00	2023-07-01 09:16:10.025477+00	20	gray	{https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0924992_pe788686_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0924993_pe788685_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0929129_pe790150_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0818543_pe774474_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0939197_pe794482_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0934665_pe792489_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0818503_pe774445_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-remmarn-light-gray__0948958_pe799429_s5.jpg?f=s}	117	f
383	2023-07-01 09:16:10.399826+00	2023-07-01 09:16:10.399849+00	20	dark gray	{https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0818571_pe774493_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0818570_pe774492_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0818546_pe774477_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0934666_pe792487_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0818506_pe774448_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-dark-turquoise__0928381_pe789853_s5.jpg?f=s}	117	f
384	2023-07-01 09:16:10.974001+00	2023-07-01 09:16:10.974028+00	20	beige	{https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0818573_pe774495_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0818572_pe774494_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0818549_pe774480_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0929130_pe790149_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0939198_pe794481_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0934667_pe792488_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0818509_pe774451_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-totebo-light-beige__0948958_pe799429_s5.jpg?f=s}	117	f
385	2023-07-01 09:16:11.657918+00	2023-07-01 09:16:11.657942+00	20	red	{https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0818575_pe774491_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0818574_pe774496_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0929131_pe790148_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0939199_pe794480_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0934668_pe792486_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0937799_pe793851_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0948958_pe799429_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/uppland-sofa-virestad-red-white__0928381_pe789853_s5.jpg?f=s}	117	f
386	2023-07-01 09:16:18.041067+00	2023-07-01 09:16:18.041092+00	20	dark gray	{https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0950864_pe800736_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0982867_pe815771_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__1059523_ph180677_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0987393_pe817515_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0987395_pe817517_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0950897_pe800737_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-dark-gray__0987394_pe817516_s5.jpg?f=s}	118	f
387	2023-07-01 09:16:18.357182+00	2023-07-01 09:16:18.357205+00	20	blue	{https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0950900_pe800740_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0981841_pe815495_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0950902_pe800742_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0987358_pe817503_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0987359_pe817504_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__1059524_ph179219_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0950901_pe800741_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/glostad-loveseat-knisa-medium-blue__0950903_pe800739_s5.jpg?f=s}	118	f
388	2023-07-01 09:16:28.368253+00	2023-07-01 09:16:28.36828+00	20	gray	{https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__1041907_pe841187_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0989588_pe818557_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0985853_pe816837_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0985836_pe816822_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0985845_pe816830_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0985826_pe816814_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-gray__0985851_pe816836_s5.jpg?f=s}	119	f
389	2023-07-01 09:16:28.781974+00	2023-07-01 09:16:28.781998+00	20	red	{https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__1041904_pe841184_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__0950178_pe800193_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__0950102_pe800231_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__0950105_pe800216_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__0950104_pe800215_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__1134558_pe878804_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-beige__1108787_pe869620_s5.jpg?f=s}	119	f
414	2023-07-01 09:21:04.683866+00	2023-07-01 09:21:04.683899+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0497160_pe628987_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0837235_pe629100_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0837233_pe628990_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0837232_pe628989_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0840815_pe629036_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-dark-blue__0612906_pe686092_s5.jpg?f=s}	123	f
390	2023-07-01 09:16:29.104998+00	2023-07-01 09:16:29.105022+00	20	dark gray	{https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__1041905_pe841185_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__0950180_pe800199_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__0950108_pe800218_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__0950110_pe800219_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__0950109_pe800228_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__1134558_pe878804_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-gunnared-dark-gray__1108787_pe869620_s5.jpg?f=s}	119	f
391	2023-07-01 09:16:29.403325+00	2023-07-01 09:16:29.403347+00	20	green	{https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__1041906_pe841186_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__0950182_pe800197_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__0986556_pe817203_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__0950112_pe800229_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__0950115_pe800222_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__1167242_ph189245_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/paerup-sofa-vissle-dark-green__0950114_pe800230_s5.jpg?f=s}	119	f
392	2023-07-01 09:16:42.937512+00	2023-07-01 09:16:42.93754+00	20	white	{https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-inseros-white__0747887_pe744745_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-inseros-white__0747886_pe744744_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-inseros-white__0819639_ph166158_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-inseros-white__0823169_pe669611_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-inseros-white__0828821_pe690372_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-inseros-white__0823167_pe669613_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-inseros-white__0891103_ph168967_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-inseros-white__0819557_pe774844_s5.jpg?f=s}	120	f
393	2023-07-01 09:16:43.264753+00	2023-07-01 09:16:43.264777+00	20	green	{https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-green__0747896_pe744765_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-green__0747895_pe744749_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-green__0810482_pe771302_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-green__0823682_pe669606_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-green__0831234_ph166232_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-green__0578883_pe669605_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-green__0823604_pe669617_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-green__0891103_ph168967_s5.jpg?f=s}	120	f
394	2023-07-01 09:16:43.629563+00	2023-07-01 09:16:43.629599+00	20	red	{https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-red__0852570_pe780176_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-red__0852571_pe780177_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-red__0852565_pe780172_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-red__0810483_pe771306_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-red__0852427_pe780066_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-red__0891103_ph168967_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-light-red__0819557_pe774844_s5.jpg?f=s}	120	f
395	2023-07-01 09:16:43.952517+00	2023-07-01 09:16:43.952543+00	20	gray	{https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-medium-gray__0747899_pe744767_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-medium-gray__0747898_pe744750_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-medium-gray__0810484_pe771304_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-medium-gray__0823577_pe669618_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-medium-gray__0895635_ph166235_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-medium-gray__0895733_ph166193_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-medium-gray__0852850_pe669596_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-ljungen-medium-gray__0578886_pe669619_s5.jpg?f=s}	120	f
396	2023-07-01 09:16:44.46504+00	2023-07-01 09:16:44.465069+00	20	dark gray	{https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-dark-gray__0747902_pe744752_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-dark-gray__0747901_pe744751_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-dark-gray__0831243_ph166233_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-dark-gray__0829594_pe690793_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-dark-gray__0578889_pe669620_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-dark-gray__0823268_pe669598_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-dark-gray__0891103_ph168967_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-dark-gray__0819557_pe774844_s5.jpg?f=s}	120	f
416	2023-07-01 09:21:05.336068+00	2023-07-01 09:21:05.336092+00	20	beige	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-light-beige__0571543_pe666957_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-light-beige__0840421_pe666960_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-light-beige__0840414_pe666959_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-light-beige__0840409_pe666958_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-light-beige__0617563_pe688046_s5.jpg?f=s}	123	f
397	2023-07-01 09:16:44.838535+00	2023-07-01 09:16:44.838559+00	20	dark gray	{https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-natural__0747905_pe744754_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-natural__0747904_pe744753_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-natural__0852830_pe669595_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-natural__0771816_pe755796_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-natural__0578892_pe669621_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-natural__0852822_pe669626_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-natural__0891103_ph168967_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/haerlanda-sectional-4-seat-with-chaise-sporda-natural__0819557_pe774844_s5.jpg?f=s}	120	f
398	2023-07-01 09:16:56.025848+00	2023-07-01 09:16:56.025871+00	20	gray	{https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056147_pe848280_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056146_pe848281_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056136_pe848268_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056148_pe848279_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1148199_ph184927_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056137_pe848269_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1056135_pe848267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tibbleby-beige-gray__1134553_pe878803_s5.jpg?f=s}	121	f
399	2023-07-01 09:16:56.464836+00	2023-07-01 09:16:56.464863+00	20	red	{https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0479956_pe619108_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0777309_pe758514_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0814739_ph166240_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0675090_ph146135_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0675091_ph146134_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0777016_pe758410_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0821977_pe625075_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-hillared-anthracite__0914082_pe783835_s5.jpg?f=s}	121	f
400	2023-07-01 09:16:56.777449+00	2023-07-01 09:16:56.777477+00	20	gray	{https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055847_pe848125_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055846_pe848126_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055792_pe848103_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055845_pe848124_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1148204_ph184815_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055811_pe848114_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1055810_pe848112_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-kelinge-gray-turquoise__1134553_pe878803_s5.jpg?f=s}	121	f
401	2023-07-01 09:16:57.066501+00	2023-07-01 09:16:57.066536+00	20	dark gray	{https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__1124126_pe875027_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__1124124_pe875028_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__1124220_pe875082_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__1124125_pe875029_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__1134553_pe878803_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-anthracite__0914082_pe783835_s5.jpg?f=s}	121	f
402	2023-07-01 09:16:57.468002+00	2023-07-01 09:16:57.468026+00	20	beige	{https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__1124123_pe875030_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__1124121_pe875025_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__1124219_pe875083_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__1124122_pe875026_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__1134553_pe878803_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kivik-sofa-with-chaise-tresund-light-beige__0914082_pe783835_s5.jpg?f=s}	121	f
403	2023-07-01 09:20:46.48404+00	2023-07-01 09:20:46.484073+00	20	dark gray	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0325432_pe517964_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__1116445_pe872501_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0750991_ph159256_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0813424_ph166295_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0836847_pe596292_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0836845_pe583755_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0325435_pe517963_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-nordvalla-dark-gray__0712904_pe729117_s5.jpg?f=s}	122	f
404	2023-07-01 09:20:46.877498+00	2023-07-01 09:20:46.87753+00	20	blue	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__1127756_pe876319_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__1127755_pe876320_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__1127752_pe876317_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__1127753_pe876318_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__1127754_pe876321_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-blue__0963366_pe808498_s5.jpg?f=s}	122	f
405	2023-07-01 09:20:47.28415+00	2023-07-01 09:20:47.284174+00	20	green	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0531313_pe647261_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0841150_pe647266_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0570380_ph145743_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0739102_ph152847_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0739101_ph155488_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0813427_ph166293_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0841141_pe647262_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-dark-green__0841145_pe647264_s5.jpg?f=s}	122	f
406	2023-07-01 09:20:47.671848+00	2023-07-01 09:20:47.671873+00	20	red	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-red-brown__1127697_pe876309_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-red-brown__1127751_pe876314_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-red-brown__1127748_pe876313_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-djuparp-red-brown__1127749_pe876316_s5.jpg?f=s}	122	f
407	2023-07-01 09:20:48.028372+00	2023-07-01 09:20:48.028396+00	20	beige	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0950941_pe800821_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__1059566_ph179098_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0950943_pe800826_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0950946_pe800823_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0950944_pe800824_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0950945_pe800825_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kelinge-beige__0963366_pe808498_s5.jpg?f=s}	122	f
408	2023-07-01 09:20:48.364095+00	2023-07-01 09:20:48.364119+00	20	blue	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kvillsfors-dark-blue-blue__0961698_pe807715_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kvillsfors-dark-blue-blue__0986935_pe817415_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kvillsfors-dark-blue-blue__0961699_pe807716_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-kvillsfors-dark-blue-blue__0961700_pe807720_s5.jpg?f=s}	122	f
409	2023-07-01 09:20:48.887047+00	2023-07-01 09:20:48.887071+00	20	yellow	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0325450_pe517970_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0837297_pe601176_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0913860_ph145337_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__1184561_ph179968_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0813426_ph166290_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0837286_pe596513_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0837284_pe583756_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-skiftebo-yellow__0325452_pe517969_s5.jpg?f=s}	122	f
410	2023-07-01 09:20:49.185873+00	2023-07-01 09:20:49.185896+00	20	black	{https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__0761768_pe751434_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__0930013_ph168645_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__1184555_ph186827_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__0761769_pe751435_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__0813433_ph166294_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__1184562_ph167261_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__1184563_ph167300_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/strandmon-wing-chair-vibberbo-black-beige__0963366_pe808498_s5.jpg?f=s}	122	f
411	2023-07-01 09:21:03.683122+00	2023-07-01 09:21:03.683147+00	20	dark gray	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0937022_pe793528_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0937023_pe793529_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0937024_pe793530_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0937025_pe793531_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-dark-gray__0612906_pe686092_s5.jpg?f=s}	123	f
412	2023-07-01 09:21:04.009025+00	2023-07-01 09:21:04.009063+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0497150_pe628977_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0837589_pe629093_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0837587_pe628980_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0837584_pe628979_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0837772_pe629026_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-anthracite__0612906_pe686092_s5.jpg?f=s}	123	f
413	2023-07-01 09:21:04.349438+00	2023-07-01 09:21:04.349461+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0497155_pe628982_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0840717_pe631653_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0840713_pe628985_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0840708_pe628984_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0841343_pe629031_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-hillared-beige__0612906_pe686092_s5.jpg?f=s}	123	f
415	2023-07-01 09:21:05.024692+00	2023-07-01 09:21:05.024718+00	20	black	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-black__0571538_pe666953_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-black__0840687_pe666956_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-black__0840685_pe666955_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-black__0840683_pe666954_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-knisa-black__0617563_pe688046_s5.jpg?f=s}	123	f
417	2023-07-01 09:21:05.777138+00	2023-07-01 09:21:05.777161+00	20	yellow	{https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-yellow__0936998_pe793510_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-yellow__0936999_pe793511_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-yellow__0937000_pe793512_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-yellow__0937001_pe793513_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-brown-skiftebo-yellow__0612906_pe686092_s5.jpg?f=s}	123	f
418	2023-07-01 09:21:13.850103+00	2023-07-01 09:21:13.850129+00	20	beige	{https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__1109687_pe870153_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__1179060_pe895831_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__1110707_pe870568_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__1109720_pe870187_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kilanda-light-beige__0940909_pe795235_s5.jpg?f=s}	124	f
419	2023-07-01 09:21:14.364811+00	2023-07-01 09:21:14.364834+00	20	gray	{https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__1109684_pe870150_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__1179059_pe895832_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__1109682_pe870149_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__1177527_ph189208_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__1109721_pe870188_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/ekenaeset-armchair-kelinge-gray-turquoise__0940909_pe795235_s5.jpg?f=s}	124	f
420	2023-07-01 09:21:20.95155+00	2023-07-01 09:21:20.951575+00	20	gray	{https://www.ikea.com/us/en/images/products/nolmyra-chair-birch-veneer-gray__0152020_pe310348_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/nolmyra-chair-birch-veneer-gray__1096307_ph161211_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/nolmyra-chair-birch-veneer-gray__1096308_ph178808_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/nolmyra-chair-birch-veneer-gray__0836779_pe585625_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/nolmyra-chair-birch-veneer-gray__1247730_ph183453_s5.jpg?f=s}	125	f
421	2023-07-01 09:21:21.758194+00	2023-07-01 09:21:21.758218+00	20	black	{https://www.ikea.com/us/en/images/products/nolmyra-chair-black-black__0169629_pe323574_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/nolmyra-chair-black-black__1096309_ph168814_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/nolmyra-chair-black-black__1061716_ph177951_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/nolmyra-chair-black-black__0256705_pe400728_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/nolmyra-chair-black-black__0840386_pe585812_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/nolmyra-chair-black-black__1247733_ph170977_s5.jpg?f=s}	125	f
422	2023-07-01 09:21:36.698079+00	2023-07-01 09:21:36.698115+00	20	beige	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0571500_pe666933_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0837298_pe666936_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0837295_pe666935_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0837285_pe666934_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0617563_pe688046_s5.jpg?f=s}	126	f
423	2023-07-01 09:21:37.269475+00	2023-07-01 09:21:37.269512+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0497120_pe628947_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837219_pe629068_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837218_pe628950_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837216_pe628949_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837772_pe629026_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0612906_pe686092_s5.jpg?f=s}	126	f
424	2023-07-01 09:21:37.613398+00	2023-07-01 09:21:37.61343+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0497125_pe628952_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__1184589_ph187101_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0837582_pe629074_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0837579_pe628955_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0837573_pe628954_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0841343_pe629031_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0612906_pe686092_s5.jpg?f=s}	126	f
425	2023-07-01 09:21:37.966937+00	2023-07-01 09:21:37.966974+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0497130_pe628957_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0840367_pe629080_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0840830_pe657554_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0837591_pe628959_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0840815_pe629036_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0612906_pe686092_s5.jpg?f=s}	126	f
426	2023-07-01 09:21:38.410104+00	2023-07-01 09:21:38.410127+00	20	black	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0571496_pe666929_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0837326_pe666932_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0837324_pe666931_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0837321_pe666930_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0617563_pe688046_s5.jpg?f=s}	126	f
516	2023-07-01 09:30:30.465893+00	2023-07-01 09:30:30.465917+00	20	blue	{https://www.ikea.com/us/en/images/products/teodores-chair-blue__1114279_pe871735_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-blue__1114277_pe871737_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-blue__1114276_pe871734_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-blue__1114278_pe871736_s5.jpg?f=s}	151	f
427	2023-07-01 09:21:38.80085+00	2023-07-01 09:21:38.800874+00	20	dark gray	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937014_pe793536_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937015_pe793537_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937016_pe793538_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0841254_pe735808_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0612906_pe686092_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937017_pe793539_s5.jpg?f=s}	126	f
428	2023-07-01 09:21:39.287682+00	2023-07-01 09:21:39.287839+00	20	yellow	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936990_pe793502_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936991_pe793517_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936992_pe793504_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936993_pe793505_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0612906_pe686092_s5.jpg?f=s}	126	f
429	2023-07-01 09:21:47.776986+00	2023-07-01 09:21:47.777015+00	20	gray	{https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-tonerud-gray__1109576_pe870068_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-tonerud-gray__1105034_pe868006_s5.jpg?f=s}	127	f
430	2023-07-01 09:21:48.114834+00	2023-07-01 09:21:48.114871+00	20	green	{https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-samsala-dark-yellow-green__1109575_pe870065_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-samsala-dark-yellow-green__1109646_pe870136_s5.jpg?f=s}	127	f
431	2023-07-01 09:21:48.466619+00	2023-07-01 09:21:48.466664+00	20	gray	{https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-samsala-gray-beige__1109578_pe870066_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jaettebo-cover-1-5-seat-module-with-storage-samsala-gray-beige__1109648_pe870137_s5.jpg?f=s}	127	f
432	2023-07-01 09:25:06.668256+00	2023-07-01 09:25:06.668289+00	20	white	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0484884_pe621348_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__1154415_pe886018_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0823861_pe775996_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0823862_pe775997_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__1154235_pe885954_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0772164_pe755890_s5.jpg?f=s}	128	f
433	2023-07-01 09:25:07.146125+00	2023-07-01 09:25:07.14615+00	20	brown	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__0484881_pe621345_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154385_pe886014_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154387_pe886016_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154386_pe886017_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154229_pe885950_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__0772164_pe755890_s5.jpg?f=s}	128	f
434	2023-07-01 09:25:07.467203+00	2023-07-01 09:25:07.467243+00	20	gray	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0750592_pe746789_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154608_pe886229_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154609_pe886231_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154610_pe886230_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0750586_pe746784_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0772164_pe755890_s5.jpg?f=s}	128	f
435	2023-07-01 09:25:07.797403+00	2023-07-01 09:25:07.797428+00	20	white	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0484883_pe621346_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154416_pe886019_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154418_pe886020_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154417_pe886021_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0381120_pe555870_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0772164_pe755890_s5.jpg?f=s}	128	f
436	2023-07-01 09:25:16.103808+00	2023-07-01 09:25:16.103843+00	20	white	{https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0627346_pe693299_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0858919_pe554983_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0385043_pe557593_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0380725_pe555604_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__0251043_pe389676_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-white-stain__1093041_pe863159_s5.jpg?f=s}	129	f
437	2023-07-01 09:25:16.426764+00	2023-07-01 09:25:16.426787+00	20	brown	{https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__0627349_pe693302_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__0132796_pe193829_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__0385084_pe557634_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__0380367_pe555288_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__0585252_ph143039_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-black-brown__1093041_pe863159_s5.jpg?f=s}	129	f
438	2023-07-01 09:25:16.872865+00	2023-07-01 09:25:16.872901+00	20	dark gray	{https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-dark-gray-stained__0519831_pe641793_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-dark-gray-stained__0519832_pe641792_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-dark-gray-stained__0520151_pe642029_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/hemnes-8-drawer-dresser-dark-gray-stained__1093041_pe863159_s5.jpg?f=s}	129	f
439	2023-07-01 09:25:28.780877+00	2023-07-01 09:25:28.780901+00	20	brown	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__0484881_pe621345_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154385_pe886014_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154387_pe886016_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154386_pe886017_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__1154229_pe885950_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-black-brown__0772164_pe755890_s5.jpg?f=s}	130	f
440	2023-07-01 09:25:29.270989+00	2023-07-01 09:25:29.271012+00	20	gray	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0750592_pe746789_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154608_pe886229_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154609_pe886231_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__1154610_pe886230_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0750586_pe746784_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-gray-stained__0772164_pe755890_s5.jpg?f=s}	130	f
441	2023-07-01 09:25:29.725959+00	2023-07-01 09:25:29.725983+00	20	white	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0484884_pe621348_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__1154415_pe886018_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0823861_pe775996_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0823862_pe775997_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__1154235_pe885954_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white__0772164_pe755890_s5.jpg?f=s}	130	f
442	2023-07-01 09:25:30.171156+00	2023-07-01 09:25:30.171194+00	20	white	{https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0484883_pe621346_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154416_pe886019_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154418_pe886020_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__1154417_pe886021_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0381120_pe555870_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-6-drawer-dresser-white-stained-oak-veneer__0772164_pe755890_s5.jpg?f=s}	130	f
443	2023-07-01 09:25:36.289656+00	2023-07-01 09:25:36.289677+00	20	brown	{https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__0651638_pe706983_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__0778046_pe758818_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__0795347_pe766006_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__0393835_pe562520_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-black-brown__1092611_pe862935_s5.jpg?f=s}	131	f
444	2023-07-01 09:25:36.864129+00	2023-07-01 09:25:36.864162+00	20	white	{https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-white__0651643_pe706985_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-white__0778050_pe758820_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-white__0795348_pe766005_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-white__0393321_pe562522_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kullen-6-drawer-dresser-white__1092611_pe862935_s5.jpg?f=s}	131	f
445	2023-07-01 09:25:43.089603+00	2023-07-01 09:25:43.089642+00	20	white	{https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__0651639_pe706984_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__0778092_pe758833_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__0858121_pe661804_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__0778096_pe758834_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-white__1092597_pe862930_s5.jpg?f=s}	132	f
446	2023-07-01 09:25:43.478961+00	2023-07-01 09:25:43.478995+00	20	brown	{https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-black-brown__0430434_pe584637_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-black-brown__0778088_pe758832_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-black-brown__0857866_pe661805_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/koppang-6-drawer-dresser-black-brown__0778102_pe758835_s5.jpg?f=s}	132	f
447	2023-07-01 09:25:53.20237+00	2023-07-01 09:25:53.202393+00	20	white	{https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__0484879_pe621344_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__1154335_pe885995_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__1154336_pe885994_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__0823860_pe775995_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__1154235_pe885954_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white__0757046_pe749103_s5.jpg?f=s}	133	f
448	2023-07-01 09:25:53.514765+00	2023-07-01 09:25:53.514787+00	20	brown	{https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-black-brown__0484876_pe621355_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-black-brown__0858161_pe624308_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-black-brown__0490153_pe624309_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-black-brown__1154229_pe885950_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-black-brown__0757046_pe749103_s5.jpg?f=s}	133	f
449	2023-07-01 09:25:53.818264+00	2023-07-01 09:25:53.818296+00	20	gray	{https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__0750599_pe746792_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__1154602_pe886225_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__1154604_pe886226_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__1154603_pe886228_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__0750586_pe746784_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-gray-stained__0757046_pe749103_s5.jpg?f=s}	133	f
450	2023-07-01 09:25:54.271305+00	2023-07-01 09:25:54.271328+00	20	white	{https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__1154347_pe886002_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__1154349_pe886001_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__1154346_pe886003_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__1154345_pe886004_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__0381120_pe555870_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-4-drawer-chest-white-stained-oak-veneer__0757046_pe749103_s5.jpg?f=s}	133	f
451	2023-07-01 09:26:41.442146+00	2023-07-01 09:26:41.442179+00	20	brown	{https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0638608_pe699032_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__1101514_pe866693_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0452610_ph133272_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__1092102_pe863044_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__1092103_pe863019_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-black-brown-luroey__0860721_pe566695_s5.jpg?f=s}	134	f
452	2023-07-01 09:26:42.155291+00	2023-07-01 09:26:42.155315+00	20	gray	{https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__0775049_pe756805_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__1101570_pe866745_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__1092106_pe863020_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__1092107_pe863021_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__0775046_pe756804_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__0750596_pe746791_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-gray-stained-luroey__0722727_pe733696_s5.jpg?f=s}	134	f
453	2023-07-01 09:26:43.065544+00	2023-07-01 09:26:43.065581+00	20	white	{https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__0749130_pe745499_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__0800857_ph163673_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__1101527_pe866706_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__1101528_pe866707_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__1101529_pe866708_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-luroey__0860683_pe566696_s5.jpg?f=s}	134	f
454	2023-07-01 09:26:43.562577+00	2023-07-01 09:26:43.56261+00	20	white	{https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__0637598_pe698416_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__1101531_pe866710_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__0734386_pe739457_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__1101532_pe866711_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__1101533_pe866712_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-bed-frame-high-white-stained-oak-veneer-luroey__0410923_pe577789_s5.jpg?f=s}	134	f
455	2023-07-01 09:26:52.965459+00	2023-07-01 09:26:52.965498+00	20	brown	{https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__1154412_pe886059_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__0735708_pe740106_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__1101552_pe866728_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__1101553_pe866678_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-black-brown-luroey__1092103_pe863019_s5.jpg?f=s}	135	f
456	2023-07-01 09:26:53.256616+00	2023-07-01 09:26:53.256639+00	20	gray	{https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1154411_pe886058_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1101595_pe866768_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__0785993_pe762843_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1101596_pe866681_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1092107_pe863021_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1154410_pe886057_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-gray-stained-luroey__1154409_pe886056_s5.jpg?f=s}	135	f
457	2023-07-01 09:26:53.661385+00	2023-07-01 09:26:53.661414+00	20	white	{https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__1154393_pe886042_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__0800857_ph163673_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__1101597_pe866769_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__1101598_pe866682_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-luroey__1101529_pe866708_s5.jpg?f=s}	135	f
458	2023-07-01 09:26:54.320172+00	2023-07-01 09:26:54.320195+00	20	white	{https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__1154398_pe886037_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__1101591_pe866765_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__0803797_ph163207_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__0800868_ph162809_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/malm-high-bed-frame-2-storage-boxes-white-stained-oak-veneer-luroey__1101592_pe866766_s5.jpg?f=s}	135	f
459	2023-07-01 09:26:59.342507+00	2023-07-01 09:26:59.34253+00	20	dark gray	{https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__0749131_pe745500_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__1102024_pe866848_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__1102025_pe866849_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__0859802_pe664779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/neiden-bed-frame-pine__0751533_pe747074_s5.jpg?f=s}	136	f
460	2023-07-01 09:27:09.750433+00	2023-07-01 09:27:09.750459+00	20	dark gray	{https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0662135_pe719104_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__1101999_pe866818_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0800859_ph163664_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0734518_pe739490_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__0738465_pe741457_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__1102000_pe866826_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-luroey__1102001_pe866827_s5.jpg?f=s}	137	f
461	2023-07-01 09:27:10.068454+00	2023-07-01 09:27:10.068486+00	20	dark gray	{https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__0662135_pe719104_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__1101999_pe866818_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__0800859_ph163664_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__0734518_pe739490_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__0738465_pe741457_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__1102000_pe866826_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__1102001_pe866827_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black__0861931_pe719102_s5.jpg?f=s}	137	f
462	2023-07-01 09:27:10.472953+00	2023-07-01 09:27:10.472984+00	20	dark gray	{https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__0662135_pe719104_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__1101999_pe866818_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__0800859_ph163664_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__0734518_pe739490_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__0738465_pe741457_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__1102000_pe866826_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__1102001_pe866827_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-black-loenset__0861931_pe719102_s5.jpg?f=s}	137	f
463	2023-07-01 09:27:11.067425+00	2023-07-01 09:27:11.067528+00	20	dark gray	{https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__0662176_pe719097_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__1101963_pe866780_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__1101964_pe866781_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__1101965_pe866782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__0861838_pe719098_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__0861814_pe713130_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/sagstua-bed-frame-white-luroey__0861829_pe713131_s5.jpg?f=s}	137	f
464	2023-07-01 09:27:19.085609+00	2023-07-01 09:27:19.085632+00	20	white	{https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__1151024_pe884762_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__1101953_pe866879_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__0800869_ph163683_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__0966529_ph175105_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__1101954_pe866880_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-white-luroey__0860776_pe659486_s5.jpg?f=s}	138	f
465	2023-07-01 09:27:19.471464+00	2023-07-01 09:27:19.471519+00	20	black	{https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__1151031_pe884735_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__1177947_pe895553_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__1101984_pe866796_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__0861220_pe659473_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-black-luroey__0780657_pe760158_s5.jpg?f=s}	138	f
517	2023-07-01 09:30:31.018274+00	2023-07-01 09:30:31.0183+00	20	green	{https://www.ikea.com/us/en/images/products/teodores-chair-green__1114283_pe871739_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-green__1114281_pe871741_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-green__1114280_pe871738_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-green__1114282_pe871740_s5.jpg?f=s}	151	f
466	2023-07-01 09:27:19.807472+00	2023-07-01 09:27:19.807557+00	20	gray	{https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0817188_pe773895_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0268303_pe406267_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0355811_pe383063_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0820603_pe775071_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0817187_pe773896_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0817186_pe773894_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/brimnes-bed-frame-with-storage-gray-luroey__0780657_pe760158_s5.jpg?f=s}	138	f
467	2023-07-01 09:27:24.976896+00	2023-07-01 09:27:24.976921+00	20	dark gray	{https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035340_pe840527_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035341_pe840528_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035343_pe840530_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035342_pe840529_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1116343_pe872489_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035350_pe840525_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kleppstad-bed-frame-white-vissle-beige__1035344_pe840531_s5.jpg?f=s}	139	f
468	2023-07-01 09:27:54.984411+00	2023-07-01 09:27:54.984446+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184928_pe898140_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184855_pe898113_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184962_pe898180_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1186815_pe898949_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184964_pe898178_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184961_pe898177_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184927_pe898141_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1045546_pe842654_s5.jpg?f=s}	140	f
469	2023-07-01 09:27:55.336967+00	2023-07-01 09:27:55.336994+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown__1022394_pe832705_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown__0977796_pe813779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown__0977786_pe813770_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown__1160031_pe888710_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown__1045546_pe842654_s5.jpg?f=s}	140	f
470	2023-07-01 09:27:55.741009+00	2023-07-01 09:27:55.741032+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-gray-turquoise__1022396_pe832707_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-gray-turquoise__0977796_pe813779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-gray-turquoise__0977774_pe813762_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-gray-turquoise__1160034_pe888714_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-gray-turquoise__1045546_pe842654_s5.jpg?f=s}	140	f
471	2023-07-01 09:27:56.274034+00	2023-07-01 09:27:56.27407+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__1022395_pe832706_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__0977796_pe813779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__0977775_pe813763_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__1160033_pe888711_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__1045546_pe842654_s5.jpg?f=s}	140	f
472	2023-07-01 09:27:56.772886+00	2023-07-01 09:27:56.772911+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__1022432_pe832720_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__0977800_pe813782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__0977775_pe813763_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__1158868_pe888215_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__1045546_pe842654_s5.jpg?f=s}	140	f
473	2023-07-01 09:27:57.189599+00	2023-07-01 09:27:57.189624+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__1022433_pe832721_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__0977800_pe813782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__0977786_pe813770_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__1045546_pe842654_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__1160047_pe888724_s5.jpg?f=s}	140	f
474	2023-07-01 09:27:57.567628+00	2023-07-01 09:27:57.567655+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-gray-turquoise__1022434_pe832718_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-gray-turquoise__0977800_pe813782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-gray-turquoise__0977774_pe813762_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-gray-turquoise__1160048_pe888725_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-gray-turquoise__1045546_pe842654_s5.jpg?f=s}	140	f
475	2023-07-01 09:28:07.88295+00	2023-07-01 09:28:07.882983+00	20	white	{https://www.ikea.com/us/en/images/products/micke-desk-white__0736018_pe740345_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0746525_ph151482_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0773258_ph161164_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0802383_ph161320_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0851508_pe565256_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0851516_pe573416_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0403463_pe565522_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white__0526706_pe645107_s5.jpg?f=s}	141	f
476	2023-07-01 09:28:08.473864+00	2023-07-01 09:28:08.473888+00	20	red	{https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0921882_pe787985_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0921883_pe787986_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0973784_ph175180_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0973786_ph175187_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0973785_ph175189_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0921885_pe787992_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0921884_pe787987_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-anthracite-red__0526706_pe645107_s5.jpg?f=s}	141	f
477	2023-07-01 09:28:09.018207+00	2023-07-01 09:28:09.018247+00	20	brown	{https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0735981_pe740299_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0798268_ph165484_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0798267_ph165486_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0798266_ph165487_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0798269_ph165483_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0403204_pe565263_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0748280_ph144536_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-black-brown__0526706_pe645107_s5.jpg?f=s}	141	f
478	2023-07-01 09:28:09.384659+00	2023-07-01 09:28:09.384692+00	20	white	{https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0921886_pe787989_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0921887_pe787990_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0973767_ph175190_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0973768_ph175202_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0973769_ph175196_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0921889_pe787988_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0921888_pe787991_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/micke-desk-white-anthracite__0526706_pe645107_s5.jpg?f=s}	141	f
479	2023-07-01 09:28:24.441329+00	2023-07-01 09:28:24.441351+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184966_pe898187_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184855_pe898113_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184962_pe898180_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1186815_pe898949_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184964_pe898178_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184961_pe898177_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1184965_pe898188_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-anthracite-white__1013518_pe829230_s5.jpg?f=s}	142	f
480	2023-07-01 09:28:24.773644+00	2023-07-01 09:28:24.773668+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-black__0977233_pe813476_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-black__0977790_pe813774_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-black__0977786_pe813770_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-black__0734618_pe739551_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-black__1028364_pe835302_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-black__1160053_pe888729_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-black__1013518_pe829230_s5.jpg?f=s}	142	f
481	2023-07-01 09:28:25.272466+00	2023-07-01 09:28:25.27249+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__0977234_pe813477_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__0977790_pe813774_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__0977775_pe813763_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__0734621_pe739540_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__1158813_pe888197_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-black-brown-white__1013518_pe829230_s5.jpg?f=s}	142	f
482	2023-07-01 09:28:25.76223+00	2023-07-01 09:28:25.762263+00	20	black	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-gray-turquoise-black__1207280_pe907882_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-gray-turquoise-black__1207279_pe907883_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-gray-turquoise-black__1207278_pe907881_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-gray-turquoise-black__1207323_pe907921_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-gray-turquoise-black__1013518_pe829230_s5.jpg?f=s}	142	f
483	2023-07-01 09:28:26.096353+00	2023-07-01 09:28:26.096377+00	20	green	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-light-green-white__1079054_pe857387_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-light-green-white__1073224_pe855660_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-light-green-white__0977775_pe813763_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-light-green-white__0734621_pe739540_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-light-green-white__1079058_pe857393_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-light-green-white__1013518_pe829230_s5.jpg?f=s}	142	f
484	2023-07-01 09:28:26.668276+00	2023-07-01 09:28:26.668309+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__0977483_pe813612_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__0977795_pe813778_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__0977775_pe813763_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__0734621_pe739540_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__1028366_pe835304_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white__1013518_pe829230_s5.jpg?f=s}	142	f
485	2023-07-01 09:28:27.039319+00	2023-07-01 09:28:27.039351+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__0977484_pe813613_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__0977795_pe813778_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__0977786_pe813770_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__0734618_pe739551_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__1159388_pe888458_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-alex-desk-white-black-brown__1013518_pe829230_s5.jpg?f=s}	142	f
486	2023-07-01 09:28:38.213172+00	2023-07-01 09:28:38.213203+00	20	gray	{https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207325_pe911159_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207323_pe907921_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207320_pe907918_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207321_pe907919_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-gray-turquoise__1207322_pe907922_s5.jpg?f=s}	143	f
487	2023-07-01 09:28:38.689657+00	2023-07-01 09:28:38.689681+00	20	brown	{https://www.ikea.com/us/en/images/products/lagkapten-tabletop-black-brown__0977796_pe813779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-black-brown__1028369_pe835306_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-black-brown__1160157_pe888780_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-black-brown__1103201_pe867210_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-black-brown__1160036_pe888715_s5.jpg?f=s}	143	f
488	2023-07-01 09:28:39.220924+00	2023-07-01 09:28:39.220955+00	20	green	{https://www.ikea.com/us/en/images/products/lagkapten-tabletop-light-green__1073229_pe855663_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-light-green__1073225_pe855661_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-light-green__1078933_pe857334_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-light-green__1078936_pe857335_s5.jpg?f=s}	143	f
489	2023-07-01 09:28:39.866121+00	2023-07-01 09:28:39.86615+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white__0977800_pe813782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white__1166683_ph182444_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white__1166682_ph184478_s5.jpg?f=s}	143	f
490	2023-07-01 09:28:40.295481+00	2023-07-01 09:28:40.295545+00	20	white	{https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1184858_pe898114_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1184855_pe898113_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1184962_pe898180_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1186815_pe898949_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1184964_pe898178_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lagkapten-tabletop-white-anthracite__1184961_pe898177_s5.jpg?f=s}	143	f
491	2023-07-01 09:28:50.966671+00	2023-07-01 09:28:50.966709+00	20	white	{https://www.ikea.com/us/en/images/products/linnmon-adils-table-white__0737165_pe740925_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white__0734654_pe739562_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white__0734621_pe739540_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white__1009784_pe827741_s5.jpg?f=s}	144	f
492	2023-07-01 09:28:51.861538+00	2023-07-01 09:28:51.861563+00	20	brown	{https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown__0974302_pe812345_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown__0734653_pe739561_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown__0734618_pe739551_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown__1009784_pe827741_s5.jpg?f=s}	144	f
493	2023-07-01 09:28:52.760342+00	2023-07-01 09:28:52.760366+00	20	brown	{https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown-white__0974303_pe812346_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown-white__0734653_pe739561_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown-white__0734621_pe739540_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-desk-black-brown-white__1009784_pe827741_s5.jpg?f=s}	144	f
494	2023-07-01 09:28:53.364938+00	2023-07-01 09:28:53.364962+00	20	black	{https://www.ikea.com/us/en/images/products/linnmon-adils-table-white-black__0737166_pe740909_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white-black__0734654_pe739562_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white-black__0734618_pe739551_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/linnmon-adils-table-white-black__1009784_pe827741_s5.jpg?f=s}	144	f
495	2023-07-01 09:29:03.376639+00	2023-07-01 09:29:03.376665+00	20	white	{https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0977775_pe813763_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__1043718_ph167220_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0995650_ph172911_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0995610_pe821781_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0995620_pe821790_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-white__0993390_pe820897_s5.jpg?f=s}	145	f
496	2023-07-01 09:29:03.724553+00	2023-07-01 09:29:03.724582+00	20	brown	{https://www.ikea.com/us/en/images/products/alex-drawer-unit-black-brown__0977786_pe813770_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-black-brown__1158870_pe888217_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-black-brown__0995608_pe821779_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-black-brown__0476104_pe616052_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-black-brown__0993390_pe820897_s5.jpg?f=s}	145	f
497	2023-07-01 09:29:04.061655+00	2023-07-01 09:29:04.061688+00	20	gray	{https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__0977774_pe813762_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__1160050_pe888728_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__1043678_ph177986_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__0995609_pe821782_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__0995619_pe821791_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/alex-drawer-unit-gray-turquoise__0993390_pe820897_s5.jpg?f=s}	145	f
498	2023-07-01 09:29:45.328289+00	2023-07-01 09:29:45.328312+00	20	beige	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0571500_pe666933_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0837298_pe666936_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0837295_pe666935_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0837285_pe666934_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-light-beige__0617563_pe688046_s5.jpg?f=s}	146	f
499	2023-07-01 09:29:45.59345+00	2023-07-01 09:29:45.593474+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0497120_pe628947_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837219_pe629068_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837218_pe628950_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837216_pe628949_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0837772_pe629026_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-anthracite__0612906_pe686092_s5.jpg?f=s}	146	f
500	2023-07-01 09:29:45.988906+00	2023-07-01 09:29:45.98894+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0497125_pe628952_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__1184589_ph187101_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0837582_pe629074_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0837579_pe628955_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0837573_pe628954_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0841343_pe629031_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-beige__0612906_pe686092_s5.jpg?f=s}	146	f
501	2023-07-01 09:29:46.437393+00	2023-07-01 09:29:46.437416+00	20	red	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0497130_pe628957_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0840367_pe629080_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0840830_pe657554_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0837591_pe628959_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0840815_pe629036_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-hillared-dark-blue__0612906_pe686092_s5.jpg?f=s}	146	f
502	2023-07-01 09:29:46.768372+00	2023-07-01 09:29:46.768399+00	20	black	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0571496_pe666929_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0837326_pe666932_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0837324_pe666931_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0837321_pe666930_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-knisa-black__0617563_pe688046_s5.jpg?f=s}	146	f
503	2023-07-01 09:29:47.277408+00	2023-07-01 09:29:47.27743+00	20	dark gray	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937014_pe793536_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937015_pe793537_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937016_pe793538_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0841254_pe735808_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0612906_pe686092_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-dark-gray__0937017_pe793539_s5.jpg?f=s}	146	f
504	2023-07-01 09:29:47.612588+00	2023-07-01 09:29:47.612639+00	20	yellow	{https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936990_pe793502_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936991_pe793517_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936992_pe793504_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0936993_pe793505_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/poaeng-armchair-birch-veneer-skiftebo-yellow__0612906_pe686092_s5.jpg?f=s}	146	f
505	2023-07-01 09:29:56.269451+00	2023-07-01 09:29:56.269491+00	20	black	{https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167042_pe891344_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167041_pe891345_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167039_pe891343_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167040_pe891346_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1167038_pe891342_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-black__1122304_pe874590_s5.jpg?f=s}	147	f
506	2023-07-01 09:29:56.574079+00	2023-07-01 09:29:56.574102+00	20	dark gray	{https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1167047_pe891349_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1167043_pe891347_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1181975_pe896902_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1167045_pe891351_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1167046_pe891350_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1167044_pe891348_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1122304_pe874590_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-chrome-plated__1195097_pe902241_s5.jpg?f=s}	147	f
528	2023-07-01 09:31:44.594286+00	2023-07-01 09:31:44.594322+00	20	dark gray	{https://www.ikea.com/us/en/images/products/billy-bookcase-birch-veneer__0252339_pe391166_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-birch-veneer__0394546_pe561369_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-birch-veneer__0850386_pe421875_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-birch-veneer__0546686_pe656298_s5.jpg?f=s}	154	f
507	2023-07-01 09:29:57.076669+00	2023-07-01 09:29:57.076697+00	20	white	{https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1167052_pe891354_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1167051_pe891355_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1181976_pe896903_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1167049_pe891353_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1167050_pe891356_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1167048_pe891352_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1122304_pe874590_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lidas-chair-black-sefast-white__1197323_pe903477_s5.jpg?f=s}	147	f
508	2023-07-01 09:30:03.680143+00	2023-07-01 09:30:03.680167+00	20	red	{https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1120081_pe873713_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1175276_ph190422_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1212386_ph191900_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1218939_ph190421_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1186082_pe898672_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1190298_ph191902_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1120079_pe873715_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-red-brown-remmarn-red-brown__1120078_pe873712_s5.jpg?f=s}	148	f
509	2023-07-01 09:30:04.065075+00	2023-07-01 09:30:04.065116+00	20	dark gray	{https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1119282_pe873451_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1190300_ph191720_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1119279_pe873450_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1186081_pe898673_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1119280_pe873453_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1119281_pe873452_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/oestanoe-chair-black-remmarn-dark-gray__1169600_pe892511_s5.jpg?f=s}	148	f
510	2023-07-01 09:30:11.146117+00	2023-07-01 09:30:11.14623+00	20	white	{https://www.ikea.com/us/en/images/products/adde-chair-white__0728280_pe736170_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__0872085_pe594884_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__0872092_pe716742_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__1052546_pe846201_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__1052547_pe846202_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__1052545_pe846250_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__0437187_pe590726_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-white__1052544_pe846199_s5.jpg?f=s}	149	f
511	2023-07-01 09:30:12.065678+00	2023-07-01 09:30:12.065713+00	20	black	{https://www.ikea.com/us/en/images/products/adde-chair-black__0728277_pe736167_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__0720893_ph004838_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__0217072_pe360544_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__1052582_pe846237_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__1052583_pe846238_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__0872127_pe594887_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__0871242_pe590544_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/adde-chair-black__1052581_pe846236_s5.jpg?f=s}	149	f
512	2023-07-01 09:30:18.971278+00	2023-07-01 09:30:18.971309+00	20	white	{https://www.ikea.com/us/en/images/products/gunde-folding-chair-white__0728314_pe736185_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-white__0872569_pe595993_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-white__0872572_pe598509_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-white__0750179_ph143072_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-white__1053267_pe846858_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-white__1053268_pe846861_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-white__0872551_pe590566_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-white__0437215_pe590754_s5.jpg?f=s}	150	f
513	2023-07-01 09:30:19.304382+00	2023-07-01 09:30:19.304408+00	20	black	{https://www.ikea.com/us/en/images/products/gunde-folding-chair-black__0728313_pe736184_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-black__0872331_pe595994_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-black__0872339_pe598523_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-black__1053269_pe846860_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-black__1053270_pe846859_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-black__0872327_pe590594_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/gunde-folding-chair-black__0997019_pe822589_s5.jpg?f=s}	150	f
514	2023-07-01 09:30:29.550492+00	2023-07-01 09:30:29.550525+00	20	white	{https://www.ikea.com/us/en/images/products/teodores-chair-white__0727344_pe735616_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-white__0870801_pe640070_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-white__0871536_pe640577_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-white__0870804_pe640576_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-white__0870808_pe716735_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-white__0949552_pe799848_s5.jpg?f=s}	151	f
515	2023-07-01 09:30:30.146277+00	2023-07-01 09:30:30.146309+00	20	black	{https://www.ikea.com/us/en/images/products/teodores-chair-black__1114240_pe871696_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-black__1114238_pe871698_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-black__1114237_pe871695_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-black__1114239_pe871697_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/teodores-chair-black__0949552_pe799848_s5.jpg?f=s}	151	f
529	2023-07-01 09:31:44.918045+00	2023-07-01 09:31:44.918071+00	20	brown	{https://www.ikea.com/us/en/images/products/billy-bookcase-black-brown__0644262_pe702535_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-black-brown__0394554_pe561377_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-black-brown__0546686_pe656298_s5.jpg?f=s}	154	f
518	2023-07-01 09:31:22.945417+00	2023-07-01 09:31:22.945443+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__0644757_pe702939_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1084790_pe859876_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1084796_pe859882_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1051325_pe845148_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1099106_pe865602_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1106842_pe868819_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white__1117445_pe872744_s5.jpg?f=s}	152	f
519	2023-07-01 09:31:23.35732+00	2023-07-01 09:31:23.357362+00	20	brown	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__0644754_pe702938_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1031126_pe836444_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1102205_pe866558_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1084789_pe859874_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1084795_pe859880_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1084783_pe859868_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-black-brown__1106841_pe868817_s5.jpg?f=s}	152	f
520	2023-07-01 09:31:23.670398+00	2023-07-01 09:31:23.670433+00	20	gray	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-gray-wood-effect__0494558_pe627165_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-gray-wood-effect__1051326_pe845149_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-gray-wood-effect__1113776_pe871541_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-gray-wood-effect__1215327_pe911964_s5.jpg?f=s}	152	f
521	2023-07-01 09:31:24.003158+00	2023-07-01 09:31:24.003181+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-high-gloss-white__0627096_pe693189_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-high-gloss-white__1051323_pe845146_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-high-gloss-white__1102294_pe866903_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-high-gloss-white__1215327_pe911964_s5.jpg?f=s}	152	f
522	2023-07-01 09:31:24.470875+00	2023-07-01 09:31:24.470904+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__0459250_pe606049_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1051324_pe845147_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1102302_pe866911_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1084797_pe859881_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1084785_pe859869_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1084791_pe859875_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-white-stained-oak-effect__1106843_pe868818_s5.jpg?f=s}	152	f
523	2023-07-01 09:31:34.661083+00	2023-07-01 09:31:34.661117+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__0754627_pe747994_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__0640671_pe699976_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__1102291_pe866900_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__1102290_pe866901_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__1051438_pe845535_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__1106842_pe868819_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white__1106846_pe868822_s5.jpg?f=s}	153	f
524	2023-07-01 09:31:35.142327+00	2023-07-01 09:31:35.142361+00	20	brown	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__0754623_pe747987_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__0640672_pe699975_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1052064_pe845908_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1051439_pe845536_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1102465_pe866994_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1092321_pe862819_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1106841_pe868817_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-black-brown__1106845_pe868820_s5.jpg?f=s}	153	f
525	2023-07-01 09:31:35.431373+00	2023-07-01 09:31:35.431398+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-high-gloss-white__0754626_pe747989_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-high-gloss-white__1102468_pe866995_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-high-gloss-white__1102467_pe866996_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-high-gloss-white__1215327_pe911964_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-high-gloss-white__1204109_pe906575_s5.jpg?f=s}	153	f
526	2023-07-01 09:31:35.874069+00	2023-07-01 09:31:35.874101+00	20	white	{https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__0480295_pe618865_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1102541_pe867020_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1102472_pe866997_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1106843_pe868818_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1106847_pe868821_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1215327_pe911964_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/kallax-shelf-unit-with-4-inserts-white-stained-oak-effect__1204109_pe906575_s5.jpg?f=s}	153	f
527	2023-07-01 09:31:44.060721+00	2023-07-01 09:31:44.060746+00	20	white	{https://www.ikea.com/us/en/images/products/billy-bookcase-white__0644260_pe702536_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-white__0394564_pe561387_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-white__0367673_ph121198_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-white__0546686_pe656298_s5.jpg?f=s}	154	f
530	2023-07-01 09:31:50.852916+00	2023-07-01 09:31:50.852952+00	20	dark gray	{https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__0981562_pe815396_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__0981563_pe815398_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__0981564_pe815397_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__0985041_pe816493_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/baggebo-shelf-unit-metal-white__1017405_pe830805_s5.jpg?f=s}	155	f
531	2023-07-01 09:31:57.965868+00	2023-07-01 09:31:57.965894+00	20	blue	{https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-dark-blue__0429309_pe584188_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-dark-blue__1051936_pe845817_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-dark-blue__0621651_ph146179_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-dark-blue__0621652_ph146129_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-dark-blue__0442517_pe593829_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-dark-blue__0507345_pe635073_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-dark-blue__0849265_pe646526_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-dark-blue__0498154_ph137137_s5.jpg?f=s}	156	f
532	2023-07-01 09:31:58.361393+00	2023-07-01 09:31:58.361417+00	20	gray	{https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-gray-metallic-effect__0806974_pe770197_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-gray-metallic-effect__0834401_pe778289_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-gray-metallic-effect__1051937_pe845818_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-gray-metallic-effect__1024325_ph178259_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-gray-metallic-effect__1065942_ph170926_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-gray-metallic-effect__1065933_ph178010_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-gray-metallic-effect__1092820_pe863070_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/billy-bookcase-with-glass-doors-gray-metallic-effect__1092821_pe863069_s5.jpg?f=s}	156	f
533	2023-07-01 09:32:07.316582+00	2023-07-01 09:32:07.316607+00	20	white	{https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white__0246565_pe385541_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white__1092772_pe863015_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white__1135810_ph178404_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white__0670330_pe715457_s5.jpg?f=s}	157	f
534	2023-07-01 09:32:07.592501+00	2023-07-01 09:32:07.592525+00	20	brown	{https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-black-brown__0670335_pe715461_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-black-brown__1092776_pe863017_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-black-brown__0670334_pe715460_s5.jpg?f=s}	157	f
535	2023-07-01 09:32:07.926341+00	2023-07-01 09:32:07.926374+00	20	white	{https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white-stained-oak-effect__0670332_pe715459_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white-stained-oak-effect__1092777_pe863046_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/lack-wall-shelf-unit-white-stained-oak-effect__0670331_pe715458_s5.jpg?f=s}	157	f
536	2023-07-01 09:32:31.469839+00	2023-07-01 09:32:31.469863+00	20	dark gray	{https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-antique-stain__0736929_pe740809_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-antique-stain__0208609_pe197452_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-antique-stain__0870916_pe716638_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-antique-stain__0870896_pe594898_s5.jpg?f=s}	158	f
537	2023-07-01 09:32:32.14218+00	2023-07-01 09:32:32.142205+00	20	brown	{https://www.ikea.com/us/en/images/products/jokkmokk-table-and-4-chairs-black-brown__0574208_pe668154_s5.jpg?f=s}	158	f
538	2023-07-01 09:32:39.1181+00	2023-07-01 09:32:39.118124+00	20	white	{https://www.ikea.com/us/en/images/products/docksta-table-white-white__0803262_pe768820_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/docksta-table-white-white__1067641_ph182537_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/docksta-table-white-white__1116272_pe872447_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/docksta-table-white-white__0803264_pe768821_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/docksta-table-white-white__0981151_pe815274_s5.jpg?f=s}	159	f
539	2023-07-01 09:32:39.424392+00	2023-07-01 09:32:39.424414+00	20	black	{https://www.ikea.com/us/en/images/products/docksta-table-black-black__1079719_pe857670_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/docksta-table-black-black__0979422_pe814531_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/docksta-table-black-black__0979425_pe814532_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/docksta-table-black-black__0981151_pe815274_s5.jpg?f=s}	159	f
540	2023-07-01 09:32:43.953226+00	2023-07-01 09:32:43.95326+00	20	black	{https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__1097254_pe864851_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__1097281_pe864868_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__0797392_pe766852_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__1053088_pe846684_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__1053089_pe846685_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__0949260_pe799598_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-nordviken-table-and-6-chairs-acacia-black__0947700_pe798621_s5.jpg?f=s}	160	f
541	2023-07-01 09:32:48.694472+00	2023-07-01 09:32:48.694497+00	20	dark gray	{https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0546603_pe656255_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__1015064_ph176248_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0946421_ph173663_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0628543_ph149771_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0809033_ph149979_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/skogsta-dining-table-acacia__0949260_pe799598_s5.jpg?f=s}	161	f
542	2023-07-01 09:32:55.673251+00	2023-07-01 09:32:55.673286+00	20	brown	{https://www.ikea.com/us/en/images/products/laneberg-stefan-table-and-4-chairs-brown-brown-black__1097706_pe865092_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/laneberg-stefan-table-and-4-chairs-brown-brown-black__1097705_pe865093_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/laneberg-stefan-table-and-4-chairs-brown-brown-black__0722960_pe733790_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/laneberg-stefan-table-and-4-chairs-brown-brown-black__1052536_pe846193_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/laneberg-stefan-table-and-4-chairs-brown-brown-black__1028128_pe835224_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/laneberg-stefan-table-and-4-chairs-brown-brown-black__1008720_pe827296_s5.jpg?f=s}	162	f
543	2023-07-01 09:32:55.993168+00	2023-07-01 09:32:55.993202+00	20	white	{https://www.ikea.com/us/en/images/products/laneberg-karljan-table-and-4-chairs-white-dark-gray-dark-gray__0745243_pe743640_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/laneberg-karljan-table-and-4-chairs-white-dark-gray-dark-gray__0745245_pe743641_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/laneberg-karljan-table-and-4-chairs-white-dark-gray-dark-gray__0798307_pe767219_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/laneberg-karljan-table-and-4-chairs-white-dark-gray-dark-gray__1028128_pe835224_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/laneberg-karljan-table-and-4-chairs-white-dark-gray-dark-gray__0948335_pe798957_s5.jpg?f=s}	162	f
544	2023-07-01 09:33:01.141805+00	2023-07-01 09:33:01.141832+00	20	red	{https://www.ikea.com/us/en/images/products/moerbylanga-lillanaes-table-and-6-chairs-oak-veneer-brown-stained-chrome-plated-gunnared-beige__1150421_pe884533_s5.jpg?f=s,https://www.ikea.com/us/en/images/products/moerbylanga-lillanaes-table-and-6-chairs-oak-veneer-brown-stained-chrome-plated-gunnared-beige__1150420_pe884538_s5.jpg?f=s}	163	f
\.


--
-- Data for Name: api_voucher; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.api_voucher (id, created_at, updated_at, is_deleted, discount, from_date, to_date, code, inventory) FROM stdin;
1	2023-06-24 10:21:47.167542+00	2023-06-24 10:21:47.167568+00	f	10	2023-05-28	2023-05-29	EVAW2021	0
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
101	31	1	Hướng dẫn và làm quen với việc luyện nghe	4	2023-06-29 07:48:25.646	2023-06-29 08:59:59.987004
102	31	2	[IELTS Intensive Reading] Chiến lược làm bài - Chữa đề - Từ vựng IELTS Reading	5	2023-06-29 09:01:43.877	2023-06-29 09:10:54.132928
111	34	3	Các phần trong TOEIC	2	2023-06-29 10:00:06.412	2023-06-29 10:02:52.254998
103	31	3	[IELTS Intensive Speaking] Thực hành luyện tập IELTS Speaking	3	2023-06-29 09:14:41.508	2023-06-29 09:18:10.976891
109	34	2	Ngữ pháp TOEIC	1	2023-06-29 09:57:38.301	2023-06-29 10:02:53.742739
104	32	1	[IELTS Fundamentals] Từ vựng và ngữ pháp cơ bản IELTS	6	2023-06-29 09:33:01.81	2023-06-29 09:39:01.131933
112	34	1	Giới thiệu về TOEIC và chiến lược làm bài	4	2023-06-29 10:02:50.75	2023-06-29 10:07:21.81897
105	32	2	[Practical English] 3600 từ vựng tiếng Anh thông dụng	6	2023-06-29 09:39:19.695	2023-06-29 09:44:03.552858
107	33	1	[Practical English] Ngữ pháp tiếng Anh từ A-Z	3	2023-06-29 09:47:40.647	2023-06-29 09:50:26.090958
108	33	2	[Practical English] Học phát âm và thực hành giao tiếp tiếng Anh	2	2023-06-29 09:51:00.945	2023-06-29 09:53:25.752139
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
1	21	31	Wow bài học này khá là chất lượng đấy <(")	1	\N	2023-06-29 09:20:29.618	2023-06-29 09:20:34.538934
2	21	31	Totally agree	0	1	2023-06-29 09:20:45.591	2023-06-29 09:20:45.591
3	22	31	Khóa học mid, cũng bình thường	0	1	2023-06-29 10:18:10.59	2023-06-29 10:18:10.59
\.


--
-- Data for Name: course; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.course (course_id, name, image, level, charges, point_to_unlock, point_reward, quantity_rating, avg_rating, participants, price, discount, total_chapter, total_lesson, total_video_time, achieves, description, created_by, created_at, updated_at) FROM stdin;
31	[IELTS Intensive Listening] Chiến lược làm bài - Chữa đề - Luyện nghe IELTS Listening theo phương pháp Dictation	http://res.cloudinary.com/doxsstgkc/image/upload/v1688024865/examify/dreamstime_s_39108012_cao1sr.jpg	advance	t	0	500	1	5.00	2	799000	10	3	12	0	<p>1️⃣ Đạt mục tiêu tối thiểu 7.0&nbsp;trong&nbsp;IELTS Listening</p><p>2️⃣ Hiểu rõ phương pháp làm các dạng câu hỏi có trong IELTS Listening</p><p>3️⃣&nbsp;Làm chủ tốc độ và các ngữ điệu khác nhau trong phần thi IELTS Listening&nbsp;</p><p>4️⃣&nbsp;Nâng cao kỹ năng nghe bắt từ khóa, nghe chính xác âm nối, âm cuối số ít / số nhiều hoặc -ed, tránh những lỗi sai thường gặp khi làm bài</p>	<blockquote><p><i>Bài học được biên soạn và giảng dạy bởi:</i></p><ul><li><i>Ms. Phuong Nguyen, Macalester College, USA. TOEFL 114, IELTS 8.0, SAT 2280, GRE Verbal 165/170</i></li><li><i>Ms. Uyen Tran, FTU. IELTS 8.0 (Listening 8.5, Reading 8.5)</i></li></ul></blockquote><p>Khoá học IELTS Intensive Listening - luyện nghe bằng phương pháp Dictation gồm 240&nbsp;bài nghe được lấy từ bộ đề Cambridge 4-17&nbsp;và BC's Official Guide to IELTS. Phương pháp dictation là một&nbsp;phương pháp học ngôn ngữ bằng cách nghe hội thoại hoặc văn bản,&nbsp;và sau đó&nbsp;viết ra những gì bạn nghe được. Đây là phương pháp vô cùng hiệu quả. STUDY4 có 3 chế độ luyện tập: dễ, trung bình và nâng cao; tăng dần&nbsp;tương ứng với số lượng ô trống bạn cần điền trong 1 câu.</p><h3><strong>Bạn sẽ học như thế nào?</strong></h3><p><strong>Nghe âm thanh</strong></p><ul><li><i>Thông qua các bài tập, bạn sẽ phải nghe rất nhiều, đó là chìa khóa để cải thiện kỹ năng nghe IELTS của bạn</i></li></ul><p><strong>Nhập những gì bạn nghe thấy</strong></p><ul><li><i>Việc gõ những gì bạn nghe được buộc bạn phải tập trung vào từng chi tiết giúp bạn trở nên tốt hơn trong việc phát âm, đánh vần và viết.</i></li></ul><p><strong>Kiểm tra và sửa chữa</strong></p><ul><li><i>Việc sửa lỗi rất quan trọng đối với độ chính xác khi nghe và khả năng đọc hiểu của bạn, tốt nhất là bạn nên highlight và lưu lại những lỗi sai mình mắc phải</i></li></ul><h3><br><strong>Chiến lược làm bài và chữa đề chi tiết</strong></h3><p><i>Khóa học cung cấp video bài giảng hướng dẫn chi tiết cách làm từng dạng câu hỏi trong IELTS Listening&nbsp;và clip chữa chi tiết&nbsp;những câu hỏi khó, chọn lọc từ bộ Cam 7-17.</i></p><figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688024732/examify/image_sizoaz.png"></figure><h3><strong>Thực hành luyện nghe&nbsp;bộ từ vựng phổ biến nhất trong phần thi IELTS Listening</strong></h3><p><i>Gần 1500 từ và cụm từ phổ biển trong phần thi IELTS Listening&nbsp;được chia thành các chủ đề như danh từ, tính từ, động từ, tiền tệ, ngày tháng, số/mã, số nhiều/số ít giúp bạn mở rộng vốn từ, nắm chắc chính tả cho dạng bài điền từ.</i></p><figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688024738/examify/image_fehsud.png"></figure><p>&nbsp;</p><h3><strong>Luyện nghe hàng ngày với phương pháp dictation (chính tả)</strong></h3><p><i>Bạn có thể luyện tập nghe điền từ hoặc chép lại cả câu. Để đạt hiệu quả tốt nhất, mỗi ngày bạn nên luyện tập ít nhất 20 phút với phương pháp này. Tốc độ nghe có thể được điều chỉnh nhanh hay chậm tùy theo khả năng của bạn.</i></p><figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688024754/examify/image_afkl9h.png"></figure><h3><br><strong>Tận dụng transcript để tập tìm keywords và học từ mới</strong></h3><p><i>Transcript được tách câu rõ ràng, kèm công cụ highlight, take note và tạo flashcards giúp bạn tận dụng tối đa transcript của bài nghe để học từ mới, luyện tập tìm keywords hoặc tra lỗi sai sau khi luyện đề xong.</i></p><p><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688024759/examify/image_xyzuol.png"><br>&nbsp;</p>	21	2023-06-29 07:47:46.616	2023-06-29 10:16:22.555204
32	 Combo khóa học IELTS lộ trình 0-7+ kèm chấm chữa giáo viên bản ngữ [Tặng khóa TED Talks]	http://res.cloudinary.com/doxsstgkc/image/upload/v1688031069/examify/2._why_take_ielts_promo_image_2-1024x585_k7iupz.jpg	basic	f	0	800	0	0.00	0	0	0	2	12	0	<p>1️⃣ Xây dựng vốn từ vựng học thuật 99% sẽ xuất hiện trong 2 phần thi Listening và Reading</p><p>2️⃣&nbsp;Làm chủ tốc độ và các ngữ điệu&nbsp;khác nhau trong phần thi IELTS Listening</p><p>3️⃣ Nắm chắc chiến thuật và phương pháp&nbsp;làm các dạng câu hỏi trong IELTS Listening và Reading</p><p>4️⃣ Xây dựng ý tưởng viết luận,&nbsp;kỹ năng viết câu, bố cục các đoạn, liên kết ý và vốn từ vựng phong phú cho các chủ đề trong IELTS Writing</p><p>5️⃣&nbsp;Luyện tập phát âm, từ vựng, ngữ pháp và thực hành luyện nói các chủ đề thường gặp và forecast trong&nbsp;IELTS Speaking</p><p>6️⃣ Được chấm chữa chi tiết (gồm điểm và nhận xét thành phần trong rubic) xác định được điểm yếu và cách khắc phục trong IELTS Speaking và Writing</p>	<h3><strong>Chiến lược làm tất cả các dạng câu hỏi IELTS Reading và Listening</strong></h3><p>Khóa học IELTS Intensive Listening và Intensive Reading cung cấp video bài giảng hướng dẫn chi tiết cách làm tất cả các dạng câu hỏi, tips làm nhanh &amp; chính xác&nbsp;và chiến lược kiểm soát thời gian hiệu quả.</p><h3><strong>Video chữa đề chi tiết bộ Cambridge&nbsp;7-17</strong></h3><p>Bộ đề thi Cambridge là tài liệu gối đầu giường của tất cả các bạn đang ôn thi IELTS, đơn giản vì đây là bộ sách do chính những người ra đề (Cambridge) viết nên độ chính xác và sát đề thi là 100%. Khóa học IELTS Intensive cung cấp clip chữa chi tiết các câu hỏi chọn lọc, độ khó cao từ bộ Cam 7-17. Mỗi bài chữa đều bao gồm phương pháp đọc câu hỏi, tìm keywords, cách tìm đáp án đúng hay lựa chọn câu trả lời phù hợp.</p><figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688031037/examify/image_bdyofq.png"></figure><p>&nbsp;</p><h3>&nbsp;</h3><h3><strong>Phương pháp luyện nghe và chép chính tả cực hiệu quả:</strong></h3><p>Khoá học IELTS Intensive Listening - luyện nghe bằng phương pháp Dictation gồm 176 bài nghe được lấy từ bộ đề Cambridge 4-16&nbsp;và BC's Official Guide to IELTS. Phương pháp dictation là một&nbsp;phương pháp học ngôn ngữ bằng cách nghe hội thoại hoặc văn bản,&nbsp;và sau đó&nbsp;viết ra những gì bạn nghe được.&nbsp;STUDY4 có 3 chế độ luyện tập: dễ, trung bình và nâng cao; tăng dần&nbsp;tương ứng với số lượng ô trống bạn cần điền trong 1 câu.</p><ul><li><strong>Nghe âm thanh</strong><ul><li><i>Thông qua các bài tập, bạn sẽ phải nghe rất nhiều, đó là chìa khóa để cải thiện kỹ năng nghe IELTS của bạn</i></li></ul></li><li><strong>Nhập những gì bạn nghe thấy</strong><ul><li><i>Việc gõ những gì bạn nghe được buộc bạn phải tập trung vào từng chi tiết giúp bạn trở nên tốt hơn trong việc phát âm, đánh vần và viết.</i></li></ul></li><li><strong>Kiểm tra và sửa chữa</strong><ul><li><i>Việc sửa lỗi rất quan trọng đối với độ chính xác khi nghe và khả năng đọc hiểu của bạn, tốt nhất là bạn nên highlight và lưu lại những lỗi sai mình mắc phải</i></li></ul></li></ul><figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688031042/examify/image_c0vo6v.png"></figure><p>&nbsp;</p><h3>&nbsp;</h3><h3><strong>Bộ từ vựng có xác&nbsp;suất&nbsp;99% sẽ xuất hiện trong phần thi&nbsp;IELTS Reading và Listening:</strong></h3><p>Bộ đề thi IELTS&nbsp;Cambridge từ lâu đã trở thành&nbsp;bộ đề tủ của bất cứ sĩ tử "cày" IELTS&nbsp;vì đây là bộ đề chính thống, chuẩn và sát thi thật&nbsp;nhất do chính những người soạn đề IELTS&nbsp;(từ trường ĐH Cambridge) viết ra.&nbsp;Theo thống kê của trung tâm luyện thi New Oriental, bộ đề IELTS Cambridge có đủ lượng từ vựng&nbsp;bạn cần để có thể "ace", i.e đạt được band 9&nbsp;trong&nbsp;phần thi IELTS Reading và Listening. Vì vậy, bên cạnh việc luyện đề, học từ mới trong bộ đề này là một việc cực kỳ quan trọng nếu bạn muốn đạt điểm cao trong 2 phần thi trên. Với mục đích giúp các bạn học viên tiết kiệm thời gian tra từ, đánh dấu cũng như có phương tiện ôn từ hiệu quả nhất,&nbsp;STUDY4 đã tổng hợp từ vựng&nbsp;trong bộ đề này thành khoá học duy nhất gồm flashcards, highlights từ vựng trong bài, và các bài tập thực hành dễ dùng dễ học.</p><figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688031049/examify/image_vr75tp.png"></figure><p>&nbsp;</p><h3>&nbsp;</h3><h3><strong>Hệ thống bài luyện tập dưới dạng game lý thú:&nbsp;</strong></h3><p>Với mỗi list từ vựng, thay vì phải làm những bài tập khô khan, bạn sẽ “phải” chơi hàng loạt trò chơi. Việc này vừa giúp việc học không hề nhàm chán, căng thẳng mà việc tiếp xúc cả hình ảnh, màu sắc, âm thanh liên quan đền từ vựng sẽ kích thích não bộ ghi nhớ nhanh hơn và lâu hơn.&nbsp;</p><p>4000 từ vựng tưởng như nhiều nhưng với phương pháp học mà chơi, chơi mà học, việc phá đảo khối lượng từ khủng như vậy hoàn toàn nằm trong lòng bàn tay bạn.&nbsp;</p><figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688031056/examify/image_hucpl3.png"></figure><p>&nbsp;</p><h3>&nbsp;</h3><h3><strong>Nắm trọn cách trả lời các dạng câu hỏi Task 1 và chủ đề thông dụng Task 2 phần thi IELTS Writing:&nbsp;</strong></h3><p>Trong khóa học IELTS Intensive Writing,&nbsp;bạn sẽ:</p><ul><li>Hiểu cấu trúc của phần thi IELTS Writing</li><li>Học cách viết câu trả lời cho&nbsp;bất kỳ&nbsp;câu hỏi Writing Task 1 và Task 2 nào sau khi học cách nhận dạng các loại câu hỏi khác nhau</li><li>Học cách tạo 'dòng chảy' trong bài luận của bạn để bạn có thể bắt đầu viết như người bản xứ bằng từ/cụm từ liên kết (cohesive devices)</li><li>Tăng lượng từ vựng của bạn một cách nhanh chóng và hiệu quả</li><li>Thực hành nhận dạng và sửa những lỗi ngữ pháp, chính tả thường gặp khi viết (mạo từ, dấu câu, mệnh đề quan hệ ...)</li><li>bắt đầu cảm thấy tự tin, yên tâm và ngày càng chuẩn bị tốt hơn cho phần thi viết trong kỳ thi IELTS tiếp theo</li></ul><p>Mỗi bài học là 1 bài luận được viết bởi một cựu giám khảo IELTS nổi tiếng như thầy Simon, Mat Clark, Mark Allen và Dave Lang. STUDY4 đã tạo ra các bài tập tương ứng giúp bạn học được tối đa mỗi bài luận, bao gồm:</p><ul><li>Học từ mới trong bài</li><li>Học từ, cụm từ liên kết các câu, ý nổi bật được sử dụng trong bài</li><li>Luyện tập tìm và sửa lỗi ngữ pháp</li><li>Học vai trò từng câu trong bài văn và luyện tập viết lại câu</li></ul><figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688031063/examify/image_o0fvzl.png"></figure><p>&nbsp;</p><h3>&nbsp;</h3><h3><strong>Thực hành luyện tập các&nbsp;chủ đề thường gặp cũng như forecast mới nhất&nbsp;Part 1, 2, 3 phần thi IELTS Speaking:&nbsp;</strong></h3><p>Trong khóa học IELTS Intensive Speaking&nbsp;này, bạn sẽ:</p><ul><li>Nắm lòng cách phát âm IPA và những yếu tố quan trọng khi nói tiếng Anh như intonation, stress, thought groups, cách trả lời các dạng câu hỏi (Wh- hay yes/no)</li><li>Hiểu cấu trúc của phần thi IELTS\b Speaking</li><li>Học cách&nbsp;trả lời cho các chủ đề part 1, 2, và 3&nbsp;thường gặp và các chủ đề mới nhất được update theo các quý</li><li>Tăng lượng từ vựng của bạn một cách nhanh chóng và hiệu quả</li><li>Thực hành nhận dạng và sửa những lỗi ngữ pháp, chính tả thường gặp khi nói</li><li>bắt đầu cảm thấy tự tin, yên tâm và ngày càng chuẩn bị tốt hơn cho phần thi nói trong kỳ thi IELTS tiếp theo</li></ul><p>Mỗi bài speaking sample được viết bởi một cựu giám khảo IELTS nổi tiếng như thầy Simon, Mat Clark, Mark Allen và Dave Lang. STUDY4 đã tạo ra các bài tập tương ứng giúp bạn học được tối đa mỗi bài, bao gồm:</p><ul><li>Học từ mới trong bài</li><li>Luyện tập tìm và sửa lỗi ngữ pháp</li><li>Thực hành luyện nói theo phương pháp shadowing</li><li>Lưu lại bài nói trên cộng đồng học tập để học hỏi từ các bạn học viên khác</li></ul><figure class="image"><img></figure><p>&nbsp;</p><h3>&nbsp;</h3><h3><strong>Chấm chữa chi tiết bài làm IELTS Speaking và Writing bởi giáo viên bản ngữ</strong></h3><p>Để đạt được điểm số cao trong hai phần thi&nbsp;IELTS Speaking và Writing là&nbsp;rất khó.&nbsp;Bất chấp mọi nỗ lực của bạn, bạn vẫn đạt được không thể vượt qua band 6.5!&nbsp;😩 Bạn cố gắng học thật chăm chỉ, tập viết và nói thật nhiều&nbsp;nhưng điểm số của bạn vẫn vậy.&nbsp;Dường như không có gì có thể đẩy bạn lên đến band 7 và 8. Tại sao?</p><p>\bSau khi làm bài, bạn cần phải được chấm chữa và nhận xét để&nbsp;biết lỗi sai của mình ở đâu và cách khắc phục chuẩn xác. Có như vậy bạn mới có thể cải thiện được trình độ.</p><p>Khóa học chấm chữa&nbsp;IELTS Writing &amp; Speaking được xây dựng nhằm giúp các bạn hiểu rõ cách làm, khắc phục điểm yếu, học cách hành văn và cải thiện nhanh chóng hai kỹ năng khó nhằn nhất trong kỳ thi IELTS. Tất cả các bài làm (gồm bài luận&nbsp;và thu âm bài nói) đều được&nbsp;chấm chữa và cho điểm chi tiết bởi đội ngũ giáo viên giàu kinh nghiệm và trình độ chuyên môn cao của STUDY4. Khi đăng ký khóa học, bạn sẽ được:</p><ul><li>Chấm chữa đầy đủ từ vựng, ngữ pháp, liên kết, nội dung</li><li>Phân tích chi tiết và lời khuyên để cải thiện</li><li>Phiếu nhận xét&nbsp;và chấm điểm chuẩn form&nbsp;IELTS</li><li>Nhận điểm từ 1-3 ngày&nbsp;sau khi nộp (trừ cuối tuần và ngày nghỉ lễ)</li></ul>	21	2023-06-29 09:31:11.357	2023-06-29 09:44:55.104066
33	Trọn bộ 3 khoá học thực hành tiếng Anh online - Practical English [Tặng khoá TED Talks]	http://res.cloudinary.com/doxsstgkc/image/upload/v1688032042/examify/Unique-Ways-to-Practice-Speaking-English-in-Washington-DC_ynpjsj.jpg	general	t	0	400	0	0.00	0	599000	0	2	5	0	<p>1️⃣ Nẵm vững các chủ điểm ngữ pháp cơ bản</p><p>2️⃣ Xây dựng vốn từ vựng thông dụng&nbsp;cho 99% ngữ cảnh</p><p>3️⃣ Nắm lòng cách phát âm 44 âm cơ bản tạo nên mọi từ trong tiếng Anh</p><p>4️⃣ Biết cách xử lý các tình huống thực tế</p><p>5️⃣ Nghe hiểu hội thoại và luyện khả năng&nbsp;phản xạ nhanh trong giao tiếp</p><p>6️⃣ Tự tin sử dụng tiếng Anh như một công cụ hiệu quả trong công việc và cuộc sống</p>	<figure class="image"><img src="https://lh6.googleusercontent.com/HVrzsZhW-yye6RpUZcqJlX7NWMCSitYCgRlSEWbL9e-VN6oYLgKk69457xZwX9FvzOkKH2-Lo1s1iHnX_d5XByg45Xn225hOLnmkjU3QaZkNHTBzNISX12R0xYdcpqRLOcqJQyHH"></figure><p>&nbsp;</p><figure class="image"><img src="https://lh6.googleusercontent.com/Pr55EZ-H9DIBItad5aUt-4lQBNaaPUpb_YArdu9y-c7MS1zppGGwSy_-K09MQWISKUlrEIf7-cuX139MyUjmy6tYjNW9rFbqYVHlT3WcoGDV_DeG2hxKXmYZeZ74vhFPO_VVyUJa"></figure><p>&nbsp;</p><figure class="image"><img src="https://lh6.googleusercontent.com/mRSseZXa5LyKpBKb_2FnUdqsKTkIyP9-m_JtVBhB2kIpzjTo1KoRaL7WHs0QHzKCZJkFP_OmS1QF__v5vnLoY1bwCwZkrSuUdOq-GFirddFAx8C62QtQU365T_D5a7wp10j5A0rG"></figure><p>&nbsp;</p><p>&nbsp;</p><figure class="image"><img src="https://lh3.googleusercontent.com/wMRfoeDXBglI3C3wJKCRQkAyBZl44GN2wJfFjH1hsK-zWw6X4Xc3O4lGSyj7FSaijpaWVrKnRfnrhLioWcG4N4A0JdIa37joTniSPcZI_vXxxJQhDXXUMv3fyvGQx9Ds3r1-FOw7"></figure><p>&nbsp;</p><p>&nbsp;</p><figure class="image"><img src="https://lh5.googleusercontent.com/6vx1lwfl_voEjvljaHXH-8yLvQtq_Qo2EPDGuBOLmFFULmEJNk8OAwWJBPZIEnxLyeDAcSZKwPo6isNd0Xs1oDkuiRskcO_iH63LSUJEajA82lwEpTyW1REooJT6dMqnBs90m2EP"></figure><p><br>&nbsp;</p>	21	2023-06-29 09:47:23.946	2023-06-29 09:53:25.752139
34	[Complete TOEIC] Chiến lược làm bài - Từ vựng - Ngữ pháp - Luyện nghe với Dictation [Tặng khoá TED Talks]	http://res.cloudinary.com/doxsstgkc/image/upload/v1688032629/examify/officelife_x5stj1.jpg	basic	f	0	300	0	0.00	0	0	0	3	7	0	<p>1️⃣ Có nền tảng ngữ pháp vững chắc&nbsp;và xây dựng vốn từ vựng 99% sẽ xuất hiện trong bài thi TOEIC</p><p>2️⃣ Cải thiện kỹ năng nghe, khắc phục các vấn đề&nbsp;khi nghe như miss thông tin, âm nối,&nbsp;tốc độ nói nhanh</p><p>3️⃣ Nắm vững cách làm tất cả&nbsp;các dạng câu hỏi trong bài thi TOEIC Listening và Reading</p>	<blockquote><p><i>Bài học được biên soạn và giảng dạy bởi:</i></p><ul><li><i>Ms. Phương Anh, FTU. 975 TOEIC</i></li></ul></blockquote><p>Khoá học Complete TOEIC do STUDY4 biên soạn và xây dựng gồm 30h học video bài giảng dạy chi tiết kỹ lưỡng tất cả các dạng câu hỏi trong bài thi TOEIC Listening và Reading, cùng hơn 1000 câu hỏi trắc nghiệm chuẩn format TOEIC mới nhất 2023 lấy từ các bộ sách ETS và Economy. Tất cả các câu hỏi bài tập đều có giải thích chi tiết, dịch nghĩa và transcript (đối với bài nghe). Ngoài ra khóa học có:</p><ul><li>Tổng hợp 1200 từ vựng TOEIC có khả năng 99% sẽ xuất hiện trong bài thi thật và 17 chủ đề ngữ pháp quan trọng nhất</li><li>Các bài luyện nghe chép chính tả (điền từ và điền câu) từ bộ ETS và New economy để học viên luyện tập kỹ năng nghe và nhanh chóng khắc phục các vấn đề thường gặp</li></ul><h3><strong>Bạn sẽ học như thế nào?</strong></h3><p><strong>Học từ vựng và ngữ pháp</strong></p><ul><li><i>Thông qua bộ flashcards 1200 từ kèm rất nhiều bài tập và các bài&nbsp;lý thuyết kèm bài tập ngữ pháp, bạn sẽ củng cố kiến thức nền Tiếng Anh.</i></li></ul><p><strong>Học cách làm các dạng câu hỏi trong bài thi TOEIC Listening và Reading</strong></p><ul><li><i>Mỗi phần thi (part 1-7) trong đề TOEIC đề có các dạng câu hỏi nhất đinh. Bạn sẽ nắm chắc cách làm qua video bài giảng lý thuyết và các câu hỏi bài tập có giải thích chi tiết.</i></li></ul><p><strong>Luyện nghe chép chính tả</strong></p><ul><li>Song song với việc học từ vựng, ngữ pháp và luyện đề, bạn sẽ được cải thiện kỹ năng nghe và khắc phục triệt để các vấn đề khi nghe với các bài tập nghe chép chính tả từ bộ ETS 20-22 và đề New Economy.</li></ul><figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688032615/examify/image_bekzpb.png"></figure><h3><strong>Học từ vựng TOEIC</strong></h3><p><i>Khóa học cung cấp 1200 từ vựng 99% sẽ xuất hiện trong bài thi TOEIC. Mỗi flashcard gồm ảnh, nghĩa tiếng Việt - tiếng Anh, phát âm, phiên âm và ví dụ. Bạn có thể luyện tập thêm các list từ với đa dạng các bài tập mini-games.</i></p><figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688032619/examify/image_d4t1gq.png"></figure><h3>&nbsp;</h3><h3><strong>Nắm chắc&nbsp;ngữ pháp&nbsp;TOEIC</strong></h3><p><i>Khóa học cung cấp 17 chủ đề ngữ pháp quan trọng kèm theo bài tập trắc nghiệm có giải thích chi tiết để bạn thực hành.</i></p><figure class="image"><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688032624/examify/image_r4m0gv.png"></figure><h3>&nbsp;</h3><h3><strong>Chiến lược và phương pháp làm bài</strong></h3><p><i>Khóa học cung cấp video bài giảng hướng dẫn chi tiết cách làm từng dạng câu hỏi trong TOEIC Reading và Listening kèm theo hơn 1000 câu hỏi trắc nghiệm có giải thích chi tiết</i></p><figure class="image"><img></figure><h3>&nbsp;</h3><h3><strong>Thực hành nghe chép chính tả TOEIC</strong></h3><p><i>Bạn có thể luyện tập nghe điền từ hoặc chép lại cả câu. Để đạt hiệu quả tốt nhất, mỗi ngày bạn nên luyện tập ít nhất 20 phút với phương pháp này. Tốc độ nghe có thể được điều chỉnh nhanh hay chậm tùy theo khả năng của bạn.</i></p><p>&nbsp;</p><p><br>&nbsp;</p>	21	2023-06-29 09:57:10.955	2023-06-29 10:07:21.81897
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
1	1	ETS TOEIC 2022 TEST 1	7	200	0	0	1	{Listening,Reading}	f	https://study4.com/media/tez_media1/sound/ets_toeic_2022_test_1_ets_2022_test01.mp3	7200	https://www.africau.edu/images/default/sample.pdf	2023-06-03 23:24:22.538932	2023-06-03 23:25:33.356635
\.


--
-- Data for Name: exam_series; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.exam_series (exam_series_id, name, total_exam, public_date, author, created_by, created_at, updated_at) FROM stdin;
2	ETS 2021	0	2020-12-13	Educational Testing Service	1	2023-06-03 23:24:22.391369	2023-06-29 09:26:33.477596
1	ETS 2022	5	2021-12-13	Educational Testing Service	1	2023-06-03 23:24:22.334961	2023-06-29 09:26:46.226464
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
201	21	abandon	to stop doing an activity before you have finished it từ bỏ, đầu hàng, không làm nữa dù chưa xong	verb	/əˈbæn.dən/	https://api.dictionaryapi.dev/media/pronunciations/en/abandon-us.mp3	The game was abandoned at half-time because of the poor weather conditions. They had to abandon their attempt to climb the mountain.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688025727/examify/mbuyjmr7jkmj7v7tbg7r.webp	21	2023-06-29 08:02:11.794	2023-06-29 08:02:11.794
202	21	abdomen	the part of the body below the chest that contains the stomach, bowels, etc vùng bụng	noun	/æbˈdəʊ.mən/	https://api.dictionaryapi.dev/media/pronunciations/en/abdomen-us.mp3			http://res.cloudinary.com/doxsstgkc/image/upload/v1688025726/examify/vc2imur0bkur8q1a30ng.webp	21	2023-06-29 08:02:11.794	2023-06-29 08:02:11.794
203	21	abdominal	connected with the the part of the body below the chest (Thuộc) Bụng; ở bụng.	adjective	/æbˈdɒm.ə.nl̩/	https://api.dictionaryapi.dev/media/pronunciations/en/abdominal-us.mp3	abdominal pains		http://res.cloudinary.com/doxsstgkc/image/upload/v1688025727/examify/rqj8dzqm8buo0d7go3yy.webp	21	2023-06-29 08:02:11.794	2023-06-29 08:02:11.794
204	21	abduct	to take somebody away illegally, especially using force [synonym] kidnap Bắt cóc, cuỗm đi, lừa đem đi	verb	/æbˈdəkt/	https://api.dictionaryapi.dev/media/pronunciations/en/abduct-us.mp3	He had attempted to abduct the two children The company director was abducted from his car by terrorists.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688025727/examify/h01jn5yk60n46ok5as4f.webp	21	2023-06-29 08:02:11.794	2023-06-29 08:02:11.794
205	21	abductor	a person who abducts somebody Người bắt cóc, người cuỗm đi, người lừa đem đi	noun	/æbˈdʌk.tə/		She was tortured by her abductors. It is thought that the woman might have known her abductor.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688025727/examify/tfppvytpbytxqvrtlycn.webp	21	2023-06-29 08:02:11.794	2023-06-29 08:02:11.794
206	21	abide	(formal) to accept and act according to a law, an agreement, etc (+ by) Tôn trọng, giữ, tuân theo, chịu theo; trung thành với	verb	/əˈbaɪd/	https://api.dictionaryapi.dev/media/pronunciations/en/abide-us.mp3	You'll have to abide by the rules of the club. We will abide by their decision		http://res.cloudinary.com/doxsstgkc/image/upload/v1688025729/examify/tcyy91fino5dy4ltqvqe.webp	21	2023-06-29 08:02:11.794	2023-06-29 08:02:11.794
207	21	ability	the physical or mental power or skill needed to do something Năng lực, khả năng (làm việc gì) (Số nhiều) Tài năng, tài cán.	noun	/əˈ.bɪl.ɪ.ti/	https://api.dictionaryapi.dev/media/pronunciations/en/ability-us.mp3	She had the ability to explain things clearly and concisely. She's a woman of considerable abilities.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688025729/examify/pazuxhh77ccbayqwm0hw.webp	21	2023-06-29 08:02:11.794	2023-06-29 08:02:11.794
208	21	abolish	to officially end a law, a system or an institution bãi bỏ, huỷ bỏ	verb	/əˈbɒlɪʃ/	https://api.dictionaryapi.dev/media/pronunciations/en/abolish-us.mp3	This tax should be abolished. I think bullfighting should be abolished National Service was abolished in the UK in 1962.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688025728/examify/muetpc9tjfsowfhqqwvw.webp	21	2023-06-29 08:02:11.794	2023-06-29 08:02:11.794
209	21	absence	the fact of somebody being away from a place where they are usually expected to be Sự vắng mặt, sự nghỉ (học), sự đi vắng; thời gian vắng mặt, lúc đi vắng.	noun	/ˈæb.s(ə)n̩s/	https://api.dictionaryapi.dev/media/pronunciations/en/absence-us.mp3	The decision was made in my absence (= while I was not there). We did not receive any news during his long absence. Unbeknown to me, he'd gone and rented out the apartment in my absence.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688025729/examify/svso1lstyf8uu6vthhcc.webp	21	2023-06-29 08:02:11.794	2023-06-29 08:02:11.794
210	21	absent	not in the place where you are expected to be, especially at school or work Vắng mặt, đi vắng, nghỉ.	verb	/ˈæb.sn̩t/	https://api.dictionaryapi.dev/media/pronunciations/en/absent-1-us.mp3	John has been absent from school/work for three days now. If a child is absent, the teacher notes it down in the class register.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688025729/examify/xhgqt6kpizvkouniwnlw.webp	21	2023-06-29 08:02:11.794	2023-06-29 08:02:11.794
211	22	abide	stay; live, dwell; continue; tolerate, put up with; wait; comply, submit, obey, conform	verb	/əˈbaɪd/	https://api.dictionaryapi.dev/media/pronunciations/en/abide-us.mp3				21	2023-06-29 08:14:34.965	2023-06-29 08:14:34.965
212	22	aboard	on, in, into (ship, train, plane, etc.)	adverb	/əˈbɔːd/	https://api.dictionaryapi.dev/media/pronunciations/en/aboard-us.mp3				21	2023-06-29 08:14:34.965	2023-06-29 08:14:34.965
213	22	absent	not present; preoccupied, lost in thought	adjective	/ˈæb.sn̩t/	https://api.dictionaryapi.dev/media/pronunciations/en/absent-1-us.mp3				21	2023-06-29 08:14:34.965	2023-06-29 08:14:34.965
214	22	absorb	suck up; take up, take in	verb	/əbˈsɔːb/	https://api.dictionaryapi.dev/media/pronunciations/en/absorb-us.mp3				21	2023-06-29 08:14:34.965	2023-06-29 08:14:34.965
215	22	accent	mode of pronunciation characteristic of a group of people or region; emphasis placed on a certain syllable in a word; mark on a letter or word showing stress or pitch; emphasis; contrasting element	noun	/ˈak.sənt/	https://api.dictionaryapi.dev/media/pronunciations/en/accent-1-uk.mp3				21	2023-06-29 08:14:34.965	2023-06-29 08:14:34.965
216	22	acceptance	act of accepting or receiving; approval; state of accepting or believing in something	noun	/ək.ˈsɛp.təns/	https://api.dictionaryapi.dev/media/pronunciations/en/acceptance-au.mp3				21	2023-06-29 08:14:34.965	2023-06-29 08:14:34.965
217	22	accessible	approachable; easily obtainable; easy to relate to; persuadable, easy to influence	adverb	/əkˈsɛs.ə.bəl/	https://api.dictionaryapi.dev/media/pronunciations/en/accessible-uk.mp3		Synonyms:nearby, available, reachable, handy, open, manageable, comprehensible, understandable, clear, straightforward, simple, approachable, affable, genial, friendly, welcoming		21	2023-06-29 08:14:34.965	2023-06-29 08:14:34.965
218	22	accessory	supplementary part; something which complements an outfit (i.e. purse, scarf, etc.); partner in crime, one who helps another commit a crime (Law)	noun	/ækˈsɛs(ə)ɹi/	https://api.dictionaryapi.dev/media/pronunciations/en/accessory-us.mp3		Synonyms:ornament, handbag, belt, scarf, gloves, accomplice, partner, assistant, abettor		21	2023-06-29 08:14:34.965	2023-06-29 08:14:34.965
219	22	acclaim	cheer for; praise, hail, extol; shout praise	verb	/ə.ˈkleɪm/	https://api.dictionaryapi.dev/media/pronunciations/en/acclaim-uk.mp3		Synonyms:approval, praise, commendation, acclamation, approbation, applause, compliments, praise, hail, commend, applaud, cheer		21	2023-06-29 08:14:34.965	2023-06-29 08:14:34.965
220	22	accommodate	host guests; provide lodging; adapt oneself; give, bestow	verb	/əˈkɒməˌdeɪt/	https://api.dictionaryapi.dev/media/pronunciations/en/accommodate-us.mp3				21	2023-06-29 08:14:34.965	2023-06-29 08:14:34.965
221	23	able	có thể	adjective	/ˈeɪ.bl̩/	https://api.dictionaryapi.dev/media/pronunciations/en/able-us.mp3	You must be able to speak Italian for this job.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688026785/examify/hqapq5jmyfghvqsexu7k.webp	21	2023-06-29 08:19:49.564	2023-06-29 08:19:49.564
222	23	accept	nhận, chấp nhận	verb	/ækˈsɛpt/	https://api.dictionaryapi.dev/media/pronunciations/en/accept-uk.mp3	We accept payment by Visa Electron, Visa, Switch, Maestro, Mastercard, JCB, Solo, check or cash.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688026785/examify/jytnyvy1y09qxpncs0jn.webp	21	2023-06-29 08:19:49.564	2023-06-29 08:19:49.564
223	23	accident	tai nạn (xe cộ...)	noun	/ˈæk.sə.dənt/	https://api.dictionaryapi.dev/media/pronunciations/en/accident-us.mp3	Example: I got injured		http://res.cloudinary.com/doxsstgkc/image/upload/v1688026786/examify/vmvqhq8nrjyehtnlpgvu.jpg	21	2023-06-29 08:19:49.564	2023-06-29 08:19:49.564
224	23	accountant	(nhân viên) kế toán	noun	/ə.ˈkæʊn.(t)ən̩(t)/		He is studying to be an accountant.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688026785/examify/kuv0bnwknmlxlzmdgrhi.webp	21	2023-06-29 08:19:49.564	2023-06-29 08:19:49.564
225	23	activity	hoạt động	noun	/ækˈtɪ.və.ti/	https://api.dictionaryapi.dev/media/pronunciations/en/activity-us.mp3	This activity makes us all laugh.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688026785/examify/hyelt2nu4gnlxb0ljjsm.webp	21	2023-06-29 08:19:49.564	2023-06-29 08:19:49.564
226	23	actor	diễn viên	noun	/ˈæk.tə/	https://api.dictionaryapi.dev/media/pronunciations/en/actor-uk.mp3	I don't have any favourite actors.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688026785/examify/hmidhtdpngk6w2f0ja5y.webp	21	2023-06-29 08:19:49.564	2023-06-29 08:19:49.564
227	23	actress	diễn viên (nữ)	noun	/ˈak.tɹəs/		She is a singer and an actress.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688026787/examify/uruuuemsa8yqxmskvhxj.webp	21	2023-06-29 08:19:49.564	2023-06-29 08:19:49.564
228	23	add	cộng vào, thêm vào	verb	/æd/	https://api.dictionaryapi.dev/media/pronunciations/en/add-us.mp3	This winter, he added skiing to his list of favorite sports.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688026787/examify/bg84ogid73camuxxuok5.webp	21	2023-06-29 08:19:49.564	2023-06-29 08:19:49.564
229	23	adult	người lớn, người trưởng thành	noun	/əˈdʌlt/	https://api.dictionaryapi.dev/media/pronunciations/en/adult-ca.mp3	He is an adult but he still likes to play with toys.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688026787/examify/vhlkheyeg6pmv3grhrvc.jpg	21	2023-06-29 08:19:49.564	2023-06-29 08:19:49.564
230	23	advise	khuyên	verb	/ədˈvaɪz/	https://api.dictionaryapi.dev/media/pronunciations/en/advise-us.mp3	We were thinking of buying that house, but our lawyer advised against it.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688026787/examify/ex9m4a3eav7vqzmdjod5.webp	21	2023-06-29 08:19:49.564	2023-06-29 08:19:49.564
231	24	evidence	bằng chứng	noun	[ˈɛvəɾəns]	https://api.dictionaryapi.dev/media/pronunciations/en/evidence-us.mp3	I was asked to give evidence(= to say what I knew, describe what I had seen, etc.) at the trial.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688027913/examify/bbvlwitudgbz8vj06nbh.jpg	21	2023-06-29 08:38:36.764	2023-06-29 08:38:36.764
232	24	evident	hiển nhiên, rõ rệt	adjective	/ˈɛ.vɪ.dənt/	https://api.dictionaryapi.dev/media/pronunciations/en/evident-us.mp3	Harry's courage during his illness was evident to everyone.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688027912/examify/sfdps2hxnv02ceszheu0.webp	21	2023-06-29 08:38:36.764	2023-06-29 08:38:36.764
233	24	evolve	phát triển	verb	/ɪˈvɒlv/	https://api.dictionaryapi.dev/media/pronunciations/en/evolve-uk.mp3	The idea evolved from a drawing I discovered in the attic.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688027912/examify/jorqtm5v7r9p2gxmaib8.jpg	21	2023-06-29 08:38:36.764	2023-06-29 08:38:36.764
234	24	exacerbate	làm tăng, làm trầm trọng thêm (bệnh, sự tức giận, sự đau đớn)	verb	/ɪkˈsæs-/	https://api.dictionaryapi.dev/media/pronunciations/en/exacerbate-us.mp3	His aggressive reaction only exacerbated the situation.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688027912/examify/yqknt2otgyrxwp3pr0tk.jpg	21	2023-06-29 08:38:36.764	2023-06-29 08:38:36.764
235	24	excavation	sự khai quật	noun			They decided to continue with the excavation.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688027912/examify/u8ntzbwv0lhdf1iqnvek.jpg	21	2023-06-29 08:38:36.764	2023-06-29 08:38:36.764
236	24	exceed	lớn hơn, vượt quá	verb	/ɪkˈsiːd/	https://api.dictionaryapi.dev/media/pronunciations/en/exceed-uk.mp3	The demand for new housing has already exceeded the supply.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688027913/examify/ebucpxqfyn8lr8wkliq2.jpg	21	2023-06-29 08:38:36.764	2023-06-29 08:38:36.764
237	24	exceptional	xuất chúng, đặc biệt	adjective	/ɪkˈsɛpʃənəl/	https://api.dictionaryapi.dev/media/pronunciations/en/exceptional-us.mp3	At the age of five he showed exceptional talent as a musician.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688027914/examify/k2mu91ieht4xnhaz0j3p.webp	21	2023-06-29 08:38:36.764	2023-06-29 08:38:36.764
238	24	exclude	loại trừ	verb	/ɪksˈkluːd/	https://api.dictionaryapi.dev/media/pronunciations/en/exclude-us.mp3	The cost of borrowing has been excluded from the inflation figures.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688027914/examify/oohsgmiwayiqycbfmtf1.jpg	21	2023-06-29 08:38:36.764	2023-06-29 08:38:36.764
239	24	exercise	sử dụng (quyền, khả năng, ...)	verb	/ˈɛk.sə.saɪz/	https://api.dictionaryapi.dev/media/pronunciations/en/exercise-us.mp3	When she appeared in court she exercised her right to remain silent.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688027914/examify/su0stgwuoqoko0sfvrtu.webp	21	2023-06-29 08:38:36.764	2023-06-29 08:38:36.764
240	24	exert	gây/tác động (để ảnh hưởng ai/cái gì)	verb	/ɪɡˈzɜːt/	https://api.dictionaryapi.dev/media/pronunciations/en/exert-us.mp3	He exerts a lot of influence on the other members of the committee.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688027914/examify/gbonoofukhett6a91zgo.jpg	21	2023-06-29 08:38:36.764	2023-06-29 08:38:36.764
241	25	REGARDLESS	in spite of. Bất chấp, không đếm xỉa tới, không chú ý tới	adverb	/ɹɪˈɡɑːd.lɪs/		The law requires equal treatment for all, regardless of race, religion, or sex.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028236/examify/www7kpagy6zbqkxhw9na.webp	21	2023-06-29 08:44:02.164	2023-06-29 08:44:02.164
242	25	REGULARLY	occurring at fixed intervals. thường xuyên, ở những quãng cách hoặc thời gian đều đặn; cách đều nhau,	adverb	/ˈɹɛɡjəli/	https://api.dictionaryapi.dev/media/pronunciations/en/regularly-us.mp3	We meet regularly, once a month.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028237/examify/jz7kt2te7xp39md9gena.webp	21	2023-06-29 08:44:02.164	2023-06-29 08:44:02.164
243	25	REIMBURSE	to pay back money spent for a specific purpose. hoàn lại, trả lại (số tiền đã tiêu)	verb		https://api.dictionaryapi.dev/media/pronunciations/en/reimburse-us.mp3	The insurance company reimbursed Donald for the cost of his trip to the emergency room		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028236/examify/okwwznly04ioryj4smvm.webp	21	2023-06-29 08:44:02.164	2023-06-29 08:44:02.164
244	25	RESTORE	to bring back to an original condition. Khôi phục lại, phục hồi	verb	/ɹɪˈstɔː/	https://api.dictionaryapi.dev/media/pronunciations/en/restore-us.mp3	The government promises to restore the economy to full strength.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028237/examify/fcsozfnukyu9yuetkmgi.webp	21	2023-06-29 08:44:02.164	2023-06-29 08:44:02.164
245	25	RESULT	an outcome. kết quả	noun	/ɹɪˈzʌlt/	https://api.dictionaryapi.dev/media/pronunciations/en/result-us.mp3	Accidents are the inevitable result of driving too fast.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028236/examify/qgcsjnnx6psit4c2ucpe.webp	21	2023-06-29 08:44:02.164	2023-06-29 08:44:02.164
246	25	SAMPLE	a portion, piece, or segment that is representative of a whole. mẫu, mẫu hàng	noun	/sæːm.pəl/		I'd like to see some samples of your work.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028236/examify/c55gqdqd0u7vmcd1ydlx.webp	21	2023-06-29 08:44:02.164	2023-06-29 08:44:02.164
247	25	SENSE	, a judgment; an intellectual interpretation. khả năng phán đoán, ý thức, giác quan	verb	/sɛn(t)s/	https://api.dictionaryapi.dev/media/pronunciations/en/sense-uk.mp3	I like Pam - she has a really good sense of humour .		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028239/examify/t3udjavvyvwuthflayzo.webp	21	2023-06-29 08:44:02.164	2023-06-29 08:44:02.164
248	25	STATEMENT	, an accounting showing an amount due; a bill. sự bày tỏ, sự trình bày, sự phát biểu	noun	/ˈsteɪtm(ə)nt/	https://api.dictionaryapi.dev/media/pronunciations/en/statement-us.mp3	In an official statement, she formally announced her resignation.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028238/examify/prub34dba9nd3ajnwhyx.webp	21	2023-06-29 08:44:02.164	2023-06-29 08:44:02.164
249	25	SUITABLE	, appropriate to a purpose or an occasion. thích hợp với	adjective	/ˈsuːtəbl/	https://api.dictionaryapi.dev/media/pronunciations/en/suitable-uk.mp3	We are hoping to find a suitable school.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028239/examify/himowjsp2anzytrxgih9.webp	21	2023-06-29 08:44:02.164	2023-06-29 08:44:02.164
250	25	SURGERY	e medical procedure that involves cutting into the body. sự phẫu thuật	noun	/ˈsɜːdʒəɹi/	https://api.dictionaryapi.dev/media/pronunciations/en/surgery-us.mp3	She required surgery on her right knee.		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028239/examify/efyaen6q5d52cxaedffh.webp	21	2023-06-29 08:44:02.164	2023-06-29 08:44:02.164
251	26	stable	ổn định	adjective	/ˈsteɪ.bəɫ/	https://api.dictionaryapi.dev/media/pronunciations/en/stable-uk.mp3	The patient's condition is stable (= it is not getting worse). (Tình trạng của bệnh nhân ổn định (= nó là không nhận được tồi tệ hơn).)		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028889/examify/nh9xflnngj2zaol7e30d.jpg	21	2023-06-29 08:54:53.439	2023-06-29 08:54:53.439
252	26	staff	đội ngũ, tập thể công nhân viên	noun	/ˈstæf/	https://api.dictionaryapi.dev/media/pronunciations/en/staff-1-us.mp3	We have 20 part-time members of staff. (Chúng tôi có 20 thành viên bán thời gian trong đội ngũ)		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028888/examify/jwpm7tkofmfvr61mziyo.webp	21	2023-06-29 08:54:53.439	2023-06-29 08:54:53.439
253	26	stapler	cái dập ghim	noun	/ˈsteɪplə/		Do you have a stapler? (Bạn có cái dập ghim không?)		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028889/examify/gptn51w0hqgsyicof20g.webp	21	2023-06-29 08:54:53.439	2023-06-29 08:54:53.439
254	26	statement	lời phát biểu, sự trình bày	noun	/ˈsteɪtm(ə)nt/	https://api.dictionaryapi.dev/media/pronunciations/en/statement-us.mp3	Your statement is misleading. (Lời phát biểu của bạn là sai lầm.)		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028889/examify/khc2vw1azakphfxxxjwl.jpg	21	2023-06-29 08:54:53.439	2023-06-29 08:54:53.439
255	26	steady	đều đặn, ổn định	adjective	/ˈstɛdi/	https://api.dictionaryapi.dev/media/pronunciations/en/steady-us.mp3	His breathing was steady. (Hơi thở của anh ấy đã ổn định.)		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028889/examify/pooxkg6isomupw6bzdcx.webp	21	2023-06-29 08:54:53.439	2023-06-29 08:54:53.439
256	26	stimulate	kích thích, khuyến khích	verb	/ˈstɪmjʊleɪt/	https://api.dictionaryapi.dev/media/pronunciations/en/stimulate-us.mp3	The economy was not stimulated by the tax cuts. (Các nền kinh tế đã không được khuyến thích bởi việc cắt giảm thuế.)		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028889/examify/uaguq8fup02poksghf1n.webp	21	2023-06-29 08:54:53.439	2023-06-29 08:54:53.439
257	26	stock	vốn; cổ phần	noun	/stɒk/	https://api.dictionaryapi.dev/media/pronunciations/en/stock-us.mp3	He owns a large share of the company's stock. (Ông ấy sở hữu một phần lớn cổ phần của công ty.)		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028891/examify/v4pzu1ca697cgwbzvr77.jpg	21	2023-06-29 08:54:53.439	2023-06-29 08:54:53.439
258	26	strategy	chiến lược	noun	/ˈstɹætədʒi/		The government is developing a strategy for dealing with unemployment. (Chính phủ đang phát triển một chiến lược để đối phó với tình trạng thất nghiệp.)		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028890/examify/lqwahpz5qq5tqdemqj04.webp	21	2023-06-29 08:54:53.439	2023-06-29 08:54:53.439
259	26	strike	cuộc đình công, cuộc bãi công	noun	/stɹaɪk/	https://api.dictionaryapi.dev/media/pronunciations/en/strike-us.mp3	The workers are on strike. (Các công nhân đang đình công.)		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028891/examify/rd8ggr7me1yuivowmclj.webp	21	2023-06-29 08:54:53.439	2023-06-29 08:54:53.439
260	26	structure	cấu trúc, cơ cấu	noun	/ˈstɹʌktʃə(ɹ)/	https://api.dictionaryapi.dev/media/pronunciations/en/structure-us.mp3	It's just a common sentencestructure. (Đó chỉ là một cấu trúc câu thông dụng.)		http://res.cloudinary.com/doxsstgkc/image/upload/v1688028891/examify/cdzmsy9mous6tsg1wls8.jpg	21	2023-06-29 08:54:53.439	2023-06-29 08:54:53.439
261	27	weather 	Thời tiết 	noun	/ˈwɛðə/	https://api.dictionaryapi.dev/media/pronunciations/en/weather-us.mp3				22	2023-06-29 10:17:06.3	2023-06-29 10:17:06.3
\.


--
-- Data for Name: flashcard_set; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.flashcard_set (fc_set_id, fc_type_id, name, description, words_count, system_belong, access, views, created_by, created_at, updated_at) FROM stdin;
26	3	Flashcards: Từ vựng tiếng Anh văn phòng	Flashcards: Từ vựng tiếng Anh văn phòng\n	10	t	public	0	21	2023-06-29 08:51:16.24	2023-06-29 08:54:53.457684
23	3	Flashcards: Từ vựng Tiếng Anh giao tiếp cơ bản	Flashcards: Từ vựng Tiếng Anh giao tiếp cơ bản	10	t	public	3	21	2023-06-29 08:15:45.701	2023-06-29 09:21:23.707396
27	\N	Test	Hello\n	1	f	\N	2	22	2023-06-29 10:16:42.609	2023-06-29 10:17:06.488734
25	2	Flashcards: 600 TOEIC words	Flashcards: 600 TOEIC words\n	10	t	public	5	21	2023-06-29 08:39:40.076	2023-06-29 23:51:54.377017
21	1	Flashcards: Cambridge Vocabulary for IELTS (20 units)	IELTS 	10	t	public	10	21	2023-06-29 07:56:18.124	2023-06-30 02:21:13.492608
24	1	Flashcards: 900 từ IELTS (có ảnh)	Flashcards: 900 từ IELTS (có ảnh)\n	10	t	public	0	21	2023-06-29 08:21:36.039	2023-06-29 08:38:36.77765
22	2	Flashcards: TOEIC Word List	TOEIC	10	t	public	0	21	2023-06-29 08:09:55.702	2023-06-29 08:14:34.979018
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
1	IELTS	Flashcard liên quan tới IELTS. Học chúng sẽ giúp bạn làm bài thi IELTS mượt như cá gặp nước.	2	2023-06-03 15:05:26.206147	2023-06-29 08:21:36.05168
2	TOEIC	Cung cấp cho bạn hàng tỉ flashcard. Bạn sẽ không còn sợ khi làm bài thi TOEIC nữa.	2	2023-06-03 15:05:26.253917	2023-06-29 08:39:40.095039
3	Từ vựng hàng ngày	10 phút mỗi ngày với những từ vựng này, sau 1 tháng bạn bỗng trở thành người bản xứ.	2	2023-06-03 15:05:26.301344	2023-06-29 08:51:16.265591
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
21	31	2023-06-29 09:19:23.732473
22	31	2023-06-29 10:16:22.555204
\.


--
-- Data for Name: join_lesson; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.join_lesson (student_id, lesson_id, created_at) FROM stdin;
21	302	2023-06-29 10:03:35.189174
21	303	2023-06-29 10:09:07.764961
\.


--
-- Data for Name: learnt_list; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.learnt_list (fc_id, user_id, created_at) FROM stdin;
\.


--
-- Data for Name: lesson; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.lesson (lesson_id, unit_id, numeric_order, name, type, video_url, video_time, flashcard_set_id, text, description, created_at, updated_at) FROM stdin;
301	201	1	Dạng bài Multiple choice	1	https://www.youtube.com/watch?v=J2X1SakiRY8&ab_channel=STUDY4	0	0		Dạng bài Multiple choice\nI. Tổng quan: \nKhái quát về dạng bài Multiple choice:\nDạng bài Multiple choice question, hay dạng bài chọn đáp án đúng, là một dạng bài phổ biến và thường xuyên xuất hiện trong kì thi IELTS. \nĐối với dạng bài này, người nghe sẽ được yêu cầu lựa chọn 1 hoặc nhiều đáp án đúng với mỗi câu hỏi mà đề bài đưa ra. \nTuy là một dạng bài trắc nghiệm, nhưng dạng bài này được đánh giá tương đối dễ nhầm lẫn vì có nhiều thông tin được đưa ra cùng một lúc trong một câu hỏi. \nĐặc điểm: \nVề hình thức, dạng bài này thường được ra dưới 2 hình thức như sau: \nShort answer multiple choice question (dạng câu hỏi với các đáp án ngắn)\nSentence completion question (dạng chọn đáp án để hoàn thành câu) \nVề dạng câu hỏi, thông thường người nghe sẽ phải lựa chọn 1 đáp án từ 3 lựa chọn được đưa ra. Tuy nhiên, một vài dạng câu hỏi sẽ yêu cầu phải chọn nhiều hơn 1 đáp án trong danh sách các lựa chọn dài hơn \nII. Phương pháp làm bài:\nTRƯỚC KHI NGHE: \n\nBước 1: Đọc kỹ yêu cầu của đề bài.\nBước 2: Đọc các câu hỏi và xác định thông tin đang được hỏi. Đánh dấu từ khóa trong câu hỏi và nghĩ đến các từ đồng nghĩa (synonyms) mà chúng ta có thể sẽ nghe thấy trong bài nghe. \nMột đặc điểm dễ thấy của IELTS nằm ở việc các câu hỏi sẽ được paraphrase (diễn đạt cùng một nội dung nhưng bằng từ ngữ khác) rất nhiều so với nội dung trong bài nghe. Việc xác định các từ khóa và liệt kê các từ cùng nghĩa hoặc đồng nghĩa của chúng sẽ giúp chúng ta hiểu rõ ý nghĩa của các ý, tránh trường hợp nhầm lẫn với thông tin gây nhiễu trong bài\n\nBước 3: Đọc các lựa chọn được đưa ra, gạch chân keywords đề nắm được ý của từng câu trả lời. Sau đó, so sánh để nhận biết sự khác nhau giữa các đáp án (differentiate A, B, C and D) . \nKhi đọc các lựa chọn được đưa ra, người nghe nên note lại những từ khóa giúp chúng ta phân biệt ý nghĩa của các lựa chọn được đưa ra. Bởi trong khi nghe, sẽ có rất nhiều thông tin nhiễu được đưa ra, nếu chúng ta không thể phân biệt được sự khác nhau giữa các đáp án. Việc chọn đáp án sai là rất dễ mắc phải.\n\nTRONG KHI NGHE: \n\nBước 4: Khi nghe, chú ý đến bất kỳ từ khóa và từ đồng nghĩa nào\nTrong đoạn audio được phát sẽ có rất nhiều thông tin gây nhiễu được nhắc tới, tuy nhiên chúng ta sẽ chỉ tập trung vào nghe từ khóa liên quan trực tiếp đến câu hỏi. Chuẩn bị sẵn tâm lý rằng các thông tin được đọc trong audio sẽ không giống hoàn toàn những từ khóa mà chúng ta sẽ gạch chân, thay vào đó, chúng có thể là những từ đồng nghĩa hoặc gần nghĩa. \n\nBước 5: Khi nghe đến đáp án mà chúng ta cho là đúng, hãy ghi chú bên cạnh và tiếp tục nghe để đảm bảo rằng đó là đáp án chính xác \nKhông nên viết chọn ngay đáp án tương ứng với câu trả lời đầu tiên mà chúng ta nghe được trong bài. Người nói có thể sẽ nói về nhiều hơn một lựa chọn vì vậy hãy đợi cho đến khi họ nói hết về chúng rồi hãy trả lời. Hãy cẩn thận với những câu trả lời được đưa ra bởi người nói và sau đó bị họ gạt đi.\n\nLưu ý: Việc nắm rõ và bám sát vào sự khác nhau giữa các đáp án được đưa ra bởi đề bài là chìa khóa giúp người nghe có thể xác định đáp án một cách chính xác và nhanh nhất. Một trong những lý do chủ yếu những thí sinh tham gia thi IELTS gặp khó khăn trong việc xử lý dạng bài tập này nằm ở việc họ không xác định được sự khác nhau giữa các lựa chọn được đưa ra, dẫn đến việc hoang mang và bối rối khi làm bài, gây mất nhiều thời gian, cũng như đáp án đưa ra không chính xác. \n\nBước 6: Lặp lại các thao tác trên cho đến khi hoàn thành bài nghe. \nIII. Một số mẹo làm bài:\n\nLuôn đọc câu hỏi trước khi nghe\nSử dụng phương pháp loại trừ để bỏ những đáp án mà chúng ta cho rằng sẽ sai và tập trung vào các đáp án còn lại. Điều này giúp chúng ta có thể định hướng thông tin và tìm kiếm một cách nhanh chóng nhất. \nĐánh dấu từ khóa. Từ khóa trong câu hỏi sẽ giúp chúng ta trả lời câu hỏi một cách chính xác. Các từ khóa trong các lựa chọn khác nhau là những từ khóa phân biệt ý nghĩa giữa các lựa chọn.  \nKhông nên viết câu trả lời đầu tiên chúng ta nghe được. Luôn nhớ rằng người nghe sẽ cố gắng đưa rất nhiều thông tin gây nhiễu để đánh lừa người thi. Hãy cẩn thận nếu chúng ta nghe thấy những từ như “but” hoặc “however”’. Điều này thường có nghĩa là người nói sẽ phủ nhận những gì họ đã nói trước đó. \nKhông dành quá nhiều thời gian cho một câu hỏi. Nếu chúng ta không nghe được câu trả lời hoặc không chắc chắn, hãy đưa ra một phỏng đoán có kiến thức và tiếp tục vì bài nghe chỉ chạy một lần duy nhất.	2023-06-29 07:51:19.113	2023-06-29 07:51:19.113
325	212	1	Past simple tense (Thì quá khứ đơn)	2		0	0	<h3><strong>Định nghĩa&nbsp;</strong></h3><p>Thì quá khứ đơn diễn tả một hành động, sự việc diễn ra và đã kết thúc trong quá khứ.</p><h3><strong>Cấu trúc</strong></h3><figure class="table"><table><tbody><tr><td><strong>Loại câu</strong></td><td><strong>Động từ thường</strong></td><td><strong>Động từ “to be”</strong></td></tr><tr><td><strong>✔ Khẳng định</strong></td><td><p>S + V2/ed + O</p><p>Ex: I saw John last night.</p><p>(Tối qua tôi đã nhìn thấy John)</p></td><td><p>S + was/were + O</p><p>Ex: I was happy yesterday. (Ngày hôm qua tôi đã rất hạnh phúc)</p></td></tr><tr><td><strong>❌Phủ định</strong></td><td><p>S + didn’t + V_inf + O</p><p>Ex: I didn’t go to work yesterday.&nbsp;</p><p>(Ngày hôm qua tôi đã không đi làm)</p></td><td><p>S + was/were + not + O</p><p>Ex: The market was not full of people yesterday. (Ngày hôm qua, chợ không đông)</p></td></tr><tr><td><strong>❓Nghi vấn</strong></td><td><p>Did + S + V_inf + O?</p><p>Ex: Did you visit James last month? (Tháng trước bạn đến thăm James phải không ?)</p></td><td><p>Was/were + S + O?</p><p>Ex: Were you tired yesterday? (Hôm qua bạn mệt phải không?</p></td></tr></tbody></table></figure><h3><strong>Cách dùng</strong></h3><figure class="table"><table><tbody><tr><td>1</td><td><p><i><strong>Diễn tả hành động đã xảy ra và chấm dứt trong quá khứ</strong></i></p><p>Ex: I went to the movie with my boyfriend 4 days ago (Tôi đi xem phim với bạn trai vào 4 ngày trước)</p><figure class="image"><img src="https://lh5.googleusercontent.com/I7AHpo9oIK936RCVcjiK9aKghNBPCDDCOlUpVhIHJ5Gw5Y90eMLEAEtaiBFku7XOUKkYk-G23P94AM7-II8oFETxpDW2eNsesmY6jUFd-a_AQ8Knc_HJbrVJMhh-izNxBVuoEG4L=s0"></figure></td></tr><tr><td>2</td><td><p><i><strong>Diễn tả một thói quen trong quá khứ.</strong></i></p><p>Ex: I used to play football with neighbor friends when I was young. (Lúc nhỏ tôi đã từng chơi đá bóng với các bạn hàng xóm)</p><figure class="image"><img src="https://lh3.googleusercontent.com/aMeY29leMDVrN1ZLmrPM3xb3WlxgVRdGJEa9a0k7q3ZhL6bXAQ7DANLQ9_Cs5PpAQ_3lLqXYnUOVJZCNhgUl0dCN_ArP_1_NOB90YREZzOk9v25qpZJCdzYhxD5mLf64V1clBMC3=s0"></figure></td></tr><tr><td>3</td><td><p><i><strong>Diễn tả chuỗi hành động xảy ra liên tiếp nhau.</strong></i></p><p>Ex: I got up, brushed my teeth and then had breakfast and went to school. (Tôi thức dậy, đánh răng rồi ăn sáng và đi học)</p></td></tr><tr><td>4</td><td><p><i><strong>Dùng trong câu điều kiện loại 2 cho về thứ nhất.</strong></i></p><p>Ex: If Linh studied hard, she could pass the entrance examination. (Nếu Linh học hành chăm chỉ, thì cô ấy đã có thể vượt qua kỳ thi đại học)</p><figure class="image"><img src="https://lh4.googleusercontent.com/GUr41tqEICUCW5aC64zq_9gIaKMLnJVnlL080swEVyEqjp0ClyS9sDMZmZcwuST-R18nlpRyq7oexrLnqEcTD1Szl7mLUuRy1jpQorQgHz-8QkNx3LoYki0Sk4839VQ89la7tbKn=s0"></figure></td></tr></tbody></table></figure><h3>&nbsp;</h3><h3><strong>Dấu hiệu nhận biết</strong></h3><p>Trong câu thường xuất hiện các từ như: <i>ago</i> (cách đây…), <i>in …, yesterday</i> (ngày hôm qua), <i>last night/month/year</i> (tối qua/ tháng trước/ năm trước).</p>	  	2023-06-29 09:48:47.273	2023-06-29 09:48:47.273
330	216	1	Danh từ	2		0	0	<h2><strong>Danh từ</strong></h2><h2><strong>1. Danh từ đếm được và danh từ không đếm được</strong></h2><h3><strong>1.1. Danh từ đếm được</strong></h3><p>Danh từ đếm được chỉ những sự việc, hiện tượng… chúng ta có thể đếm được. Danh từ đếm được có 2 dạng: số ít và số nhiều.</p><p>VD: His uncle owns a factory/ factories.</p><p><i>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Chú của anh ấy sở hữu một nhà máy/ nhiều nhà máy.&nbsp;</i></p><figure class="table"><table><tbody><tr><td colspan="3"><strong>Cách viết danh từ số nhiều</strong></td></tr><tr><td><p>Phần lớn danh từ: thêm -s</p><p>Danh từ tận cùng là -ch, -sh, -s, -x: thêm -es</p><p>Danh từ tận cùng là phụ âm + -y: bỏ -y, thêm -ies</p><p>Một số danh từ tận cùng là -f/-fe: bỏ -f/-fe, thêm -vies</p><p>Danh từ số nhiều bất quy tắc</p></td><td><p>book -&gt; books</p><p>church -&gt; churches</p><p>party -&gt; parties</p><p>leaf -&gt; leaves&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</p><p>man -&gt; men</p></td><td><p>cup -&gt; cups</p><p>dish -&gt; dishes</p><p>city -&gt; cities</p><p>knife -&gt; knives</p><p>child -&gt; children</p></td></tr></tbody></table></figure><h3><strong>1.2. Danh từ không đếm được</strong></h3><p>Danh từ không đếm được chỉ những sự việc, hiện tượng… chúng ta không thể đếm được. Danh từ không đếm được không có khái niệm số ít và số nhiều.</p><figure class="table"><table><tbody><tr><td colspan="4"><strong>Những danh từ không đếm được thường gặp trong bài thi TOEIC</strong></td></tr><tr><td><p>information: <i>thông tin</i></p><p>advice: <i>lời khuyên</i></p></td><td><p>furniture: <i>đồ đạc</i></p><p>machinery: <i>máy móc</i></p></td><td>luggage: <i>hành lý</i></td><td>equipment: <i>thiết bị</i></td></tr></tbody></table></figure><p>VD: They are checking&nbsp;the <strong>equipment </strong>(an equipment, equipments)</p><ul><li>Lưu ý: Danh từ không đếm được có thể kết hợp với các cụm từ như: <strong>a piece of, two pieces of, several pieces of,</strong>... để diễn tả số lượng</li></ul><p>VD: They are checking <strong>several pieces of equipment</strong>.</p><p>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Họ đang kiểm tra <strong>vài thiết bị.</strong>&nbsp;</p><h2><strong>2. Từ hạn định</strong></h2><h3><strong>2.1. Khái niệm</strong></h3><p>Từ đi kèm với danh từ đếm được và danh từ không đếm được đã đề cập ở phần trước là từ hạn định. Từ hạn định đóng vai trò giới hạn ý nghĩa của danh từ. Chẳng hạn nếu nói <strong>factory&nbsp;</strong>(nhà máy) thì người nghe rất khó nhận biết đó là nhà máy&nbsp;nào, nhưng nếu thêm <i><strong>a, his, this</strong></i>,... phía trước <strong>factory&nbsp;</strong>thì người ta sẽ hiểu rõ hơn.</p><p>VD: He works in a/ his/ this factory.</p><p>Ngoài ra còn có 1 số lý do nữa khiến từ hạn định đóng vai trò quan trọng, đó là quy tắc: <strong>danh từ đếm được số ít bắt buộc phải có từ hạn định đi kèm.&nbsp;</strong></p><p>VD: He works in <strong>a factory&nbsp;</strong>(factory)</p><h3><strong>2.2. Đặc điểm</strong></h3><p>Từ hạn định bao gồm nhiều loại từ: <strong>mạo từ, tính từ sở hữu, đại từ chỉ định, từ chỉ số lượng… </strong>Bạn cần nắm vững các đặc điểm của từ hạn định để phân biệt nó với tính từ (vì&nbsp;cả từ hạn định lẫn tính từ đều đứng trước danh từ).</p><ul><li>Mỗi danh từ chỉ có <strong>một từ hạn định đi kèm</strong>. Nhưng một danh từ có thể có nhiều tính từ cùng bổ nghĩa cho nó.</li></ul><figure class="table"><table><tbody><tr><td><strong>Từ hạn định</strong></td><td>I bought <strong>a chair</strong> (a this chair, a your chair, a and your chair)</td></tr><tr><td><strong>Tính từ</strong></td><td><p>I bought a <strong>small round wooden chair.</strong></p><p><strong>&nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; TT&nbsp;1&nbsp; &nbsp; TT&nbsp;2&nbsp; &nbsp; &nbsp; TT&nbsp;3</strong></p></td></tr></tbody></table></figure><ul><li>Khi danh từ có cả từ hạn định và tính từ đi kèm thì <strong>từ hạn định sẽ đứng trước tính từ</strong>.</li></ul><p>VD: <strong>This new model </strong>is in store next week.&nbsp;</p><p>&nbsp;&nbsp;&nbsp;&nbsp; <strong>&nbsp;THĐ + TT</strong> (New this)</p><h2><strong>3. Các loại từ hạn định và cách dùng:</strong></h2><h3><strong>3.1. Mạo từ bất định và mạo từ xác định</strong></h3><ul><li>Mạo từ bất định <strong>a(n)</strong></li></ul><p><strong>A(n)</strong> được gọi là mạo từ bất định vì nó diễn tả một người/vật không được xác định rõ. Mạo từ bất định đứng trước danh từ đếm được số ít và bạn không nhất thiết phải dịch nghĩa. <strong>A </strong>đi với phần lớn danh từ đếm được số ít, <strong>an</strong> đi với những danh từ bắt đầu bằng nguyên âm (<strong>a, e, i, o, u</strong>), hay nói chính xác hơn là bắt đầu bằng những âm nguyên âm; <i>ví </i>dụ: <strong>an example, an hour</strong>. Lưu ý là <strong>mạo từ bất định không kết hợp với danh từ không đếm được.</strong></p><ul><li>Mạo từ xác định <strong>the</strong></li></ul><p><i>The</i> được dùng với các danh từ chỉ người hoặc vật đã được xác định rõ.</p><figure class="table"><table><tbody><tr><td><strong>Mạo từ</strong></td><td><strong>Danh từ đếm được</strong></td><td><strong>Danh từ không đếm được</strong></td></tr><tr><td><p>a(n)</p><p>the</p></td><td><p><strong>a </strong>machine, machines</p><p><strong>the </strong>machine, the machines</p></td><td><p><strong>a </strong>machinery</p><p><strong>the </strong>machinery</p></td></tr></tbody></table></figure><h3><strong>3.2. Các từ hạn định khác</strong></h3><ul><li>Tính từ sở hữu: Tính từ sở hữu đứng trước danh từ và diễn tả khái niệm sở hữu (của ai).</li><li>Đại từ chỉ định: Bao gồm <strong>this /these</strong> <i>(này),</i> <strong>that/those</strong> <i>(kia).</i> Lưu ý là <strong>these </strong>và <strong>those </strong>đi với danh từ đếm được số nhiều.</li><li>Từ chỉ số lượng: <strong>many/ much</strong> <i>(nhiều),</i> <strong>a few/ a little</strong> <i>(một it),</i> <strong>each </strong><i>(mỗi),</i> <strong>every </strong><i>(mọi), </i><strong>some </strong><i>(một vài, một ít),</i> <strong>most </strong><i>(phần lớn),</i> <strong>all </strong><i>(tất cả)...</i></li></ul><figure class="table"><table><tbody><tr><td rowspan="2"><strong>Từ hạn định</strong></td><td colspan="2"><strong>Danh từ đếm được</strong></td><td rowspan="2"><strong>Danh từ không đếm được</strong></td></tr><tr><td><strong>Số ít</strong></td><td><strong>Số nhiều</strong></td></tr><tr><td><p>his</p><p>this/ that</p><p>these/ those</p><p>many/ a few/ few</p><p>much/ a little/ little</p><p>each, every</p><p>some, most, all</p></td><td><p><strong>his </strong>employee</p><p><strong>this </strong>employee</p><p>-</p><p>-</p><p>-</p><p><strong>each </strong>employee</p><p>-</p></td><td><p><strong>his </strong>employees</p><p>-</p><p><strong>these </strong>employees</p><p><strong>many </strong>employees</p><p>-</p><p>-</p><p><strong>some </strong>employees</p></td><td><p><strong>his </strong>information</p><p><strong>this </strong>information</p><p>-</p><p>-</p><p><strong>much </strong>information</p><p>-</p><p><strong>some </strong>information</p></td></tr></tbody></table></figure><ul><li><strong>Ghi nhớ 1</strong>: Những danh từ có dạng số nhiều đặc biệt</li></ul><figure class="table"><table><tbody><tr><td><ul><li><strong>customs</strong></li><li><strong>goods</strong></li><li><strong>valuables&nbsp;</strong></li><li><strong>surroundings</strong></li></ul></td><td><ul><li><strong>earnings</strong></li><li><strong>means</strong></li><li><strong>belongings</strong></li><li><strong>physics</strong></li></ul></td></tr></tbody></table></figure><p>Một số danh từ khi được dùng ở dạng số nhiều sẽ có nghĩa hoàn toàn khác so với khi ; được dùng <i>ở</i> dạng số ít, chẳng hạn <strong>custom </strong>có nghĩa là <i>tập quán</i> nhưng <strong>customs </strong>lại có nghĩa là <i>hải quan.</i> Có từ không phải là danh từ nhưng khi thêm -s thì trở thành danh từ số nhiều (bị thay đổi từ loại), chẳng hạn <strong>valuable </strong>(có <i>giá trị)</i> là tính từ, khi thêm -s thì trở thành danh từ số nhiều <strong>valuables </strong><i>(các vật có giá trị).</i></p><p>VD: They sell household&nbsp;<strong>goods </strong>as well as food.&nbsp;</p><p><i>Họ bán đồ gia dụng và&nbsp;thực phẩm.&nbsp;</i>&nbsp; &nbsp;&nbsp;</p><p>The company's&nbsp;<strong>earnings </strong>this year<strong>&nbsp;</strong>will increase at least&nbsp;15 percent.</p><p>Thu nhập của công ty năm nay sẽ tăng ít nhất 15%.</p><p>&nbsp;He lives&nbsp;in very comfortable <strong>surroundings.</strong></p><p><strong>&nbsp;</strong><i>Anh ấy sống&nbsp;trong <strong>điều kiện/ môi trường</strong> rất&nbsp;thoải mái.</i></p><p>Ngoài ra, bạn cần lưu ý là tên các môn học tuy có dạng số nhiều nhưng chúng là những&nbsp; danh từ không đếm được, chẳng hạn <strong>physics </strong><i>(vật lý học),</i> <strong>economics </strong><i>(kinh tế học),</i> <strong>mathematics</strong> <i>(toán học),</i> <strong>statistics </strong><i>(thống kê)...</i></p><ul><li><strong>Ghi nhớ 2</strong>: Hình thức số ít, số nhiều của danh từ ghép:</li></ul><figure class="table"><table><tbody><tr><td><strong>Số ít</strong></td><td><strong>Số nhiều</strong></td></tr><tr><td><ul><li><strong>a </strong>sports complex</li><li><strong>a </strong>benefits package</li><li><strong>a </strong>savings bank</li><li><strong>an </strong>awards ceremony</li></ul></td><td><ul><li>sports complex<strong>es</strong>&nbsp;</li><li>benefits package<strong>s</strong></li><li>savings bank<strong>s</strong></li><li>awards ceremon<strong>ies</strong></li></ul></td></tr></tbody></table></figure><p>Với danh từ ghép (được tạo thành từ hai danh từ trở lên) thì <strong>danh từ đứng cuối</strong> <strong>sẽ quyết định hình thức số ít hay số nhiều.</strong> Nêu danh từ đứng cuối ở dạng số ít thì danh từ ghép ở dạng số ít, nếu danh từ đứng cuối ở dạng số nhiều thì danh từ ghép ở dạng số nhiều.</p><p>VD: <strong>This benefits package </strong>is good.</p><p>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <i>Gói lợi ích này&nbsp;tốt.</i></p><p><strong>Many music awards shows </strong>are held weekly.</p><p><i>Nhiều chương trình giải thưởng âm nhạc được tổ chức hàng tuần.</i></p><h2><strong>4. Tóm tắt</strong></h2><h3><strong>4.1. Danh từ đếm được và danh từ không đếm được</strong></h3><ul><li><strong>A(n)</strong> đứng trước danh từ đếm được số ít; <strong>-(e)s </strong>được thêm vào sau danh từ đếm được để tạo dạng số nhiều.</li><li>Danh từ không đếm được không đi với <strong>a(n)</strong> và không có dạng số nhiều.</li></ul><h3><strong>4.2. Từ hạn định</strong></h3><ul><li>Từ hạn định được dùng trước danh từ để giới hạn ý nghĩa của danh từ đó.</li><li>Từ hạn định bao gồm mạo từ, tính từ sở hữu, đại từ chỉ định, từ chỉ số lượng...</li><li>Trước mỗi danh từ chỉ có một từ hạn định.</li><li>Khi danh từ có cả từ hạn định lẫn tính từ đi cùng thì chúng được sắp xếp theo thứ tự: từ hạn định + tính từ + danh từ.</li><li><strong>Ghi nhớ 1:</strong></li><li>Những danh từ có dạng số nhiều đặc biệt: <strong>customs, goods, valuables, surroundings, earnings, means, belongings, physics.</strong>..</li><li><strong>Ghi nhớ 2:</strong></li><li>Danh từ đứng cuối sẽ quyết định hình thức số&nbsp;ít hay số nhiều của một danh từ ghép.</li></ul>	 	2023-06-29 09:58:58.599	2023-06-29 09:58:58.599
302	201	2	Chữa đề Cam 16 Test 3 Part 3	1	https://www.youtube.com/watch?v=9lew4PGIDHE&ab_channel=STUDY4	0	0		 	2023-06-29 07:52:33.715	2023-06-29 07:52:33.715
326	213	1	Verb + object + to infinitive (Động từ + tân ngữ + ĐT nguyên mẫu có 'to')	2		0	0	<p>Trong tiếng Anh, một số động từ được theo sau bởi tân ngữ và động từ nguyên thể có "to".&nbsp;</p><p>Cấu trúc:&nbsp;</p><p><i><strong>V + O + to V = Động từ + Tân ngữ + Động từ nguyên thể có "to"</strong></i></p><p>Ví dụ:</p><figure class="table"><table><tbody><tr><td><i>Chủ ngữ</i></td><td><i>Động từ</i></td><td><i>Tân ngữ</i></td><td><i>(not) to + infinitive</i></td><td>&nbsp;</td></tr><tr><td>Marco’s mother</td><td>ordered</td><td>him</td><td>to get into</td><td>the car.</td></tr><tr><td>Elena</td><td>told</td><td>the children</td><td>not to touch</td><td>the glasses.</td></tr></tbody></table></figure><p>&nbsp;</p><p>Ở thể phủ định, ta thêm “not” vào trước “to V”.</p><p>Ví dụ:</p><ul><li>She told me<strong> not to go</strong> out. (Cô ấy bảo tôi không nên ra ngoài.)</li><li>Her father warned her <strong>not to accept </strong>his invitation. (Bố của cô ấy cảnh báo cô không nên chấp nhận lời mời của anh ta.)</li></ul><figure class="image"><img src="https://lh4.googleusercontent.com/OYHhJEhRgV35r02w9NEfJlved0LstgR1CmvfjAspEDvXOElQ_NsLjfMYJoHQ8UH1rwDxD_awiH6XfPufj7DjspaRn1ubLfEAYP-PVoloQvU3TF2h2ciIUK42bBgEgMrrQAgQ2rjY=s0"></figure><figure class="image"><img src="https://lh3.googleusercontent.com/8Lehed_gcI4M7FHiGcZ94RxydrMuFnabp5-lAGu3Rcd4tGI_68HdkI6hVS_iX1le_bRqml0zWnKcGaBaEEzptUACvCJ6B5UOmr7nyWPIZ1koFS3KPf64TPrj7P_qGP_V5E8DQv82=s0" alt="V + O + to V: Động từ đi kèm tân ngữ và động từ nguyên thể"></figure><p>Động từ theo sau bởi tân ngữ và động từ nguyên thể có "to", cũng xuất hiện ở thể bị động.</p><p>Ví dụ:</p><ul><li>The students <i>were instructed</i> <strong>to line up</strong> in pairs. (Học sinh được chỉ dẫn xếp hàng theo cặp.)</li><li>After days of pointless fighting, the marines <i>were ordered </i><strong>to withdraw.</strong></li><li>I <strong>was told</strong> <i>to give up</i> smoking.</li></ul><h3><strong>Một số động từ thường đi với tân ngữ và động từ nguyên thể có "to"</strong></h3><figure class="table"><table><tbody><tr><td><i><strong>Động từ</strong></i></td><td><i><strong>Nghĩa</strong></i></td><td><i><strong>Ví dụ</strong></i></td></tr><tr><td>afford</td><td>đủ tiền làm gì</td><td>I can’t afford <strong>to go </strong>on holiday. (Tôi không có đủ tiền đi du lịch.)</td></tr><tr><td>demand</td><td>yêu cầu</td><td>I demand <strong>to see</strong> the manager. (Tôi yêu cầu gặp người quản lý.)</td></tr><tr><td>like</td><td>thích làm gì</td><td>He likes <strong>to spend</strong> his evenings in front of the television. (Anh ấy thích dành buổi tối xem TV.)</td></tr><tr><td>pretend</td><td>giả vờ</td><td>Were you just pretending<strong> to be </strong>interested? (Có phải cầu vừa giả vờ tỏ ra thích thú?)</td></tr><tr><td>agree</td><td>đồng tình</td><td>They agreed not <strong>to tell</strong> anyone about what had happened. (Họ đồng ý không kể cho ai về việc đã xảy ra.)</td></tr><tr><td>fail</td><td>thất bại</td><td>She failed<strong> to reach</strong> the Wimbledon Final this year. (Cô ấy đã thất bại trong việc đạt vào vòng chung kết Wimbledon năm nay.)</td></tr><tr><td>love</td><td>yêu thích</td><td>The very fact that you are seeking<strong> to find</strong> what you love to do is a big step. (Sự thật là tìm kiếm thứ mà bạn yêu thích là một bước đi lớn.)</td></tr><tr><td>promise</td><td>hứa</td><td>He promised faithfully <strong>to call</strong> me every week. (Anh ta hứa chân thành rằng sẽ gọi tôi hàng tuần.)</td></tr><tr><td>arrange</td><td>sắp xếp</td><td>They arranged <strong>to have</strong> dinner the following month. (Họ đang sắp xếp ăn tối vào tháng sau.)</td></tr><tr><td>forget</td><td>quên</td><td>Don't forget <strong>to lock</strong> the door. (Đừng quên khóa cửa.)</td></tr><tr><td>manage</td><td>xoay sở</td><td>A small dog had somehow managed <strong>to survive </strong>the fire. (Chú chó nhỏ đã làm cách nào đó để sống sót khỏi vụ hỏa hoạn.)</td></tr><tr><td>refuse</td><td>từ chối</td><td>On cold mornings the car always refuses <strong>to start</strong>. (Vào những buổi sáng trời lạnh, luôn khó khởi động.)</td></tr><tr><td>ask</td><td>đề nghị</td><td>You should ask your accountant <strong>to give</strong> you some financial advice. (Bạn nên nhờ kế toán của bạn đưa ra một số lời khuyên tài chính.)&nbsp;</td></tr><tr><td>hate</td><td>không muốn,ghét</td><td>I hate (= do not want)<strong> to interrupt</strong>, but it's time we left. (Tôi không muốn chen ngang, nhưng đến lúc chúng ta phải đi rồi.)</td></tr><tr><td>mean (= intend)</td><td>ý định</td><td>Do you think she meant<strong> to say</strong> 9 a.m. instead of 9 p.m.? (Cậu có nghĩ cô ý định nói là 9h sáng thay vì 9h tối không?)</td></tr><tr><td>remember</td><td>nhớ</td><td>Did you remember <strong>to ring</strong> Nigel? (Cậu có nhớ gọi Nigel không?)</td></tr><tr><td>help</td><td>giúp đỡ</td><td>The $10,000 loan from the bank helped her <strong>to start</strong> her own business. (Khoản vay 10000 đô từ ngân hàng đa giúp cô ấy khởi nghiệp.)</td></tr><tr><td>begin</td><td>bắt đầu</td><td>It began <strong>to rain</strong>. (Trời bắt đầu mưa.)</td></tr><tr><td>need</td><td>cần</td><td>Most people need <strong>to feel </strong>loved. (Hầu hết mọi người cần cảm thấy được yêu thương.)</td></tr><tr><td>start</td><td>bắt đầu</td><td>I'd just started<strong> to write</strong> a letter when the phone rang. (Tôi chỉ mới bắt đầu viết thư khi điện thoại kêu.)</td></tr><tr><td>choose</td><td>chọn</td><td>Katie chose <strong>to stay</strong> away from work that day. (Katie chọn không động tới công việc trông ngày hôm ấy.)</td></tr><tr><td>hope</td><td>hi vọng</td><td>She hopes<strong> to go</strong> to university next year. (Cô ấy hi vọng sẽ đi học đại học vào năm tới.)</td></tr><tr><td>offer</td><td>đề nghị</td><td>My father offered<strong> to take</strong> us to the airport. (Bố tôi đề nghị đưa chúng tôi ra sân bay.)</td></tr><tr><td>try</td><td>cố gắng</td><td>I tried<strong> to open</strong> the window. (Tôi đã cố gắng mở cửa sổ.)</td></tr><tr><td>continue</td><td>tiếp tục</td><td>It's said that as the boat went down the band continued <strong>to play</strong>. (Người ta nói khi thuyền chìm, ban nhạc tiếp tục chơi.)</td></tr><tr><td>intend</td><td>dự định</td><td>We intend <strong>to go</strong> to Australia next year. (Chúng tôi dự định đi Úc vào năm tới.)</td></tr><tr><td>plan</td><td>kế hoạch</td><td>I'm not planning<strong> to stay </strong>here much longer. (Tôi không định ở lại đây lâu hơn.)</td></tr><tr><td>want</td><td>muốn</td><td>What do you want <strong>to eat? </strong>(Bạn muốn ăn gì?)</td></tr><tr><td>decide</td><td>quyết định</td><td>In the end, we decided <strong>to go</strong> to the theatre. (Cuối cùng chúng tôi quyết định đi đến nhà hát.)</td></tr><tr><td>learn</td><td>học</td><td>My mother never learnt <strong>to swim</strong>. (Mẹ tôi chưa bao giờ học bơi.)</td></tr><tr><td>prefer</td><td>thích làm gì hơn</td><td>I'd prefer not <strong>to discuss </strong>this issue. (Tôi không muốn bàn về vấn đề này.)</td></tr></tbody></table></figure><p>&nbsp;</p><p><strong>Lưu ý: </strong>Không dùng “suggest” với cấu trúc “verb+object+to”:</p><p>Ví dụ:</p><ul><li>Jane suggested that I should buy a car. (không phải “Jane suggested me to buy” &gt; Jane đã đề nghị tôi nên mua một chiếc&nbsp; xe hơi.)</li></ul><p><i>Một số động từ đi với V-ing hoặc Object + to V:</i></p><ul><li>advise&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</li><li>recommend</li><li>encourage&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</li><li>allow</li><li>permit&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</li><li>forbid</li></ul><p>Ví dụ:</p><p><i><strong>verb+ -ing (without an object)</strong></i></p><ul><li>I wouldn’t <strong>recommend staying </strong>in that hotel. (Tôi sẽ không khuyên bạn ở khách sạn đó.)</li><li>She doesn’t <strong>allow smoking </strong>in the house. (Cô ấy không cho phép hút thuốc trong nhà.)</li></ul><p><i><strong>verb+object+to</strong></i></p><ul><li>I wouldn’t<strong> recommend anybody to stay</strong> in that hotel. (Tôi không khuyên ai đến ở khách sạn đó)</li><li>She doesn’t <strong>allow us to smoke </strong>in the house. (Cô ấy không cho phép chúng tôi hút thuốc trong nhà)</li></ul><figure class="image"><img src="https://lh4.googleusercontent.com/gTD5h_yBhBHSLX9TpHOfOqBhT2VazxvFvQ2w4ytlj8wvQ74fQW50jpNlEdvgHc7MamoT-J1klP_wyQ9cHs52VhGRO-CmLBY_FD6ewmbSMsoJWQeQMrxYOI1NNrC7JN_LHke4rZlD=s0"></figure><figure class="image"><img src="https://lh5.googleusercontent.com/uiRieuZ533LNWumd7BG-CkyTnCEMZmRAbzg82sDigZ75zYXKyiOxYO6_W9U3Y1n9Ve5otL-tUICbpi3gqL4YzLZ9Zv19FoKwQrvhEr_re_ar4hUlJwb1TTJAyGQYk2H6ycedrQbN=s0"></figure><p>Trường hợp “make” và “let”: Hai động từ này đi với cấu trúc “verb+object+infinitive” (không có to)</p><p>Ví dụ:</p><ul><li>The customs officer <strong>made Sally open</strong> her case. (không nói 'to open' &gt; Các nhân viên hải quan đã buộc Sally mở va li của cô ấy)</li><li>Hot weather <strong>makes me feel </strong>tired. (causes me to feel tired &gt; Thời tiết nóng nực làm tôi cảm thấy mệt mỏi)</li><li>Her parents wouldn’t <strong>let her go</strong> out alone. (=wouldn't allow her to go out &gt; Cha mẹ cô ấy sẽ không cho phép cô ấy ra khỏi nhà một mình)</li><li><strong>Let me carry</strong> your bag for you. (Hãy để tôi mang giúp túi xách của anh)</li></ul><p>Chúng ta nói “make somebody do...” (không nói 'to do'), nhưng dạng thụ động là “(be) made to do...” (infinitive có to):</p><p>Sally <strong>was made to open</strong> her case. (by the customs officer) &gt; Sally đã bị buộc phải mở va li. (bởi các nhân viên hải quan)</p>	 	2023-06-29 09:49:55.618	2023-06-29 09:49:55.618
331	217	1	Câu hỏi về chủ đề, mục đích	1	https://www.youtube.com/watch?v=_5PijqLwmtk&ab_channel=STUDY4	0	0		Câu hỏi về chủ đề, mục đích của cuộc hội thoại \n1. Đặc điểm chung\nCâu hỏi thông tin tổng quát thường là câu hỏi đầu tiên trong số 3 câu mỗi đoạn hội thoại, yêu cầu người nghe phải nắm được vấn đề đang được bàn luận, nói đến trong đoạn hội thoại.\nThông tin để trả lời câu hỏi này sẽ nằm ở phần đầu của cuộc hội thoại.\nCác câu hỏi thông tin chung thường là:\nWhat are the speakers (mainly) discussing?\nWhat is the man/ the woman concerned about?\nWhat is the problem?\nWhy does the man/ the woman call?\nWhat is the reason for John's call?\n2. Phân tích ví dụ\nExample 1:\nAudio (ETS 2021 - Test 3 - Q38)\n\nĐọc câu hỏi:\nQ: What are the speakers discussing? => Dạng câu hỏi về chủ đề, mục đích \n\nNgười nói đang bàn luận việc gì?        => Nghe thông tin ở những câu đầu tiên\n\n(A) A fundraiser\n\n      Một buổi gây quỹ\n\n(B) A health fair\n\n      Một hội chợ về sức khỏe\n\n(C) A facility tour\n\n      Một chuyến tham quan nhà máy\n\n(D) A business trip\n\n      Một chuyến công tác\n\n Đọc và nhớ nhanh thông tin \n\nNghe băng:\nWoman: Takumi, I'm planning to attend the company health fair on Monday. Would you be interested in going together?\n\nMan: Oh, I'm on vacation next week. I did go last year-it was really great. I learned some exercises and stretches that are helpful for office workers like us. I still do them every day.\n\nChọn đáp án\nThông tin xuất hiện ở ngay câu đầu tiên: I'm planning to attend the company health fair on Monday. (Tôi đang tính dự hội chợ sức khỏe của công ty vào thứ Hai). Từ khóa: the company health fair. \n\n=> Chọn (B) \n\nCách nói về dự định, kế hoạch: I'm planning to + V\n\nExample 2: \nAudio (New Economy - Test 4 - Q38)\n\nĐọc câu hỏi:\nQ: What problem is the woman reporting? \n\n     Người phụ nữ báo cáo vấn đề gì? \n\n(A) An accounting error has been made.\n\n      Lỗi kế toán \n\n(B) A printer is out of order.\n\n      Máy in hỏng\n\n(C) Some office supplies have been used up.\n\n      Hết văn phòng phẩm\n\n(D) A document has become lost.\n\n      Mất tài liệu\n\nLưu ý: đọc nhanh và nhớ ngắn gọn các đáp án để tránh mất thời gian và bị lẫn lộn thông tin. Mặc dù đáp án viết dưới dạng 1 câu dài nhưng ta chỉ cần nhớ ý chính. \n\nNghe băng:\nWoman: Hello, this is Kelly in the accounting department. The ink cartridge in the printer on the fourth floor has run out. Do you think you could come to replace it today? \n\nMan: Sure. By the way, can I ask you a favor? I need you to let me know what model the machine is so I can bring the correct one. Actually, I'm not in the office right now, so I can't see what it is. \n\nChọn đáp án: \nCâu chứa đáp án: The ink cartridge in the printer on the fourth floor has run out.\n\n(Hộp mực máy in ở tầng 4 bị hết mất rồi)\n\nMặc dù trong số 4 đáp án không có xuất hiện the ink cartridge nhưng có cụm từ paraphrase của has run out = have been used up\n\nvà the ink cartridge là một trong những office supplies \n\n=> Chọn (C)\n\nKết luận: So sánh example 1 và 2, ta thấy được cùng là dạng câu hỏi về chủ đề mục đích nhưng: \n\n- Example 1: từ khóa trong bài và trong câu hỏi trùng nhau. Các đáp án ngắn và dễ nhớ. \n\n- Example 2: từ khóa trong bài và trong câu hỏi được paraphrase toàn bộ. Các đáp án là câu dài. \n\n=> Cần luyện tập đọc hiểu và nghe hiểu thông tin thay vì nhớ và chờ nghe key word.\n\n3. Lưu ý tránh bẫy\nThông tin nhiễu \nXem lại example 2: \n\nQ: What problem is the woman reporting? \n\n     Người phụ nữ báo cáo vấn đề gì? \n\n(A) An accounting error has been made.\n\n      Lỗi kế toán \n\n(B) A printer is out of order.\n\n      Máy in hỏng\n\n(C) Some office supplies have been used up.\n\n      Hết văn phòng phẩm\n\n(D) A document has become lost.\n\n      Mất tài liệu\n\nScript:\n\nWoman: Hello, this is Kelly in the accounting department. The ink cartridge in the printer on the fourth floor has run out. Do you think you could come to replace it today? \n\nMan: Sure. By the way, can I ask you a favor? I need you to let me know what model the machine is so I can bring the correct one. Actually, I'm not in the office right now, so I can't see what it is. \n\n=> Trong 2 câu đầu đã xuất hiện từ accounting và printer là thông tin gây nhiễu vì các từ này có xuất hiện trong đáp án (A) và (B). Nếu thí sinh chỉ chăm chăm đợi nghe từ khóa và không hiểu thì rất dễ chọn sai đáp án. \n\nParaphrase\nNhư đã phân tích ở phần 2. Đáp án đúng cho ví dụ đã được paraphrase. Một cách paraphrase được sử dụng phổ biến là dùng danh từ chỉ chung để nói về một vật cụ thể. VD: ink cartridge => some office supplies, \n\n=> Học từ vựng   	2023-06-29 10:00:54.877	2023-06-29 10:00:54.877
303	202	1	Luyện nghe với flashcard phần 1	3		0	21		 	2023-06-29 08:59:15.495	2023-06-29 08:59:15.495
327	213	2	Causative verbs (Động từ khởi phát)	2		0	0	<p>Động từ khởi phát bao gồm các động từ rất hay dùng như <i>have, get, make, let, help</i>. Đây đều là những động từ có nhiều cách dùng theo nhiều cấu trúc, công thức khác nhau và mang nghĩa theo từng ngữ cảnh.&nbsp;</p><p>&nbsp;1. Động từ khởi phát là gì?</p><p>&nbsp;Loại động từ này có tên tiếng Anh là “causative verbs”, hay còn có tên gọi khác là động từ nguyên nhân. Rất nhiều người học tiếng Anh không biết causative verbs là gì thế nhưng khi nhắc đến danh sách các từ trong nhóm này, chúng ta lại đều rất quen thuộc và hiểu ngay vấn đề.</p><p>Động từ khởi phát được hiểu là những động từ gây ra hành động khác nữa, là nguyên nhân của hành động. Vậy nên cách dùng động từ khởi phát không giống với những động từ thông thường. Chúng bao gồm: let, make, have, get, help. Các động từ khởi phát này có thể xuất hiện ở mọi thì tiếng Anh và trong tất cả câu trần thuật, nghi vấn, cảm thán hay cầu khiến.</p><figure class="image"><img src="https://lh6.googleusercontent.com/7I15wmjsCrcrKR0RzUfSnRPhRVzGonNw442PF-dKdFRr6hMgJfCVNQlr8R1c0MqnUvUB1N0mcViepoiCY05VAL3s__3xZPIB2ZtmmNopgZwq684VxuWgPvTG4HAzVwns4p52w36T=s0"></figure><h2><strong>2. Cách dùng động từ khởi phát</strong></h2><figure class="table"><table><tbody><tr><td><i><strong>Động từ</strong></i></td><td><i><strong>Nghĩa và cấu trúc</strong></i></td><td><i><strong>Ví dụ</strong></i></td></tr><tr><td><strong>let</strong></td><td><p>Cho phép ai làm gì đó</p><p><i>LET + somebody + động từ</i></p></td><td><p>My mother let me come home late at night.</p><p>(Mẹ tôi cho phép tôi về nhà muộn ban đêm.)</p></td></tr><tr><td><strong>make</strong></td><td><p>Bắt ai đó phải làm việc gì đó</p><p><i>MAKE + somebody + động từ</i></p></td><td><p>My father makes me clean the living room.</p><p>(Bố tôi bắt tôi lau dọn phòng khách.)</p></td></tr><tr><td rowspan="2"><strong>have</strong></td><td><p>Nhờ ai đó làm việc gì đó cho mình (mình chủ động nhờ)</p><p><i>HAVE + somebody + động từ</i></p></td><td>I had John wash my car. (Tôi nhờ John rửa ô tô của tôi.)</td></tr><tr><td><p>Nhờ ai đó làm việc gì đó cho mình (bị động):</p><p><i>HAVE + something + V-ed/past participle</i></p><p>Lưu ý: có thể dùng get thay cho have trong trường hợp này khi ngữ cảnh không trang trọng.</p></td><td>I had my car washed. (Tôi nhờ (ai đó) rửa ô tô của tôi.)</td></tr><tr><td rowspan="2"><strong>get</strong></td><td><p>Thuyết phục/bắt ai đó làm việc gì đó cho mình:</p><p><i>GET + somebody + to V</i></p></td><td>I got my sister to help me with my homework. (Tôi thuyết phục được chị gái giúp mình làm bài tập về nhà.)</td></tr><tr><td><p>Làm cho vật đó thực hiện hành động nào đó:</p><p><i>GET + something + V-ing</i></p></td><td>Can you get that old motorbike going again? (Bạn có thể làm cho cái xe máy cũ đó chạy được lại không?)</td></tr><tr><td><strong>help</strong></td><td><p>Giúp đỡ ai đó làm việc gì đó:</p><p><i>HELP + somebody + V nguyên thể</i></p><p><i>HELP + somebody + To Verb</i></p></td><td><p>He helped me carry the bag.</p><p>= He helped me to carry the bag.</p><p>Anh ấy giúp tôi cầm cái túi.</p></td></tr></tbody></table></figure><p>&nbsp;</p><h2><strong>Cách sử dụng cấu trúc make</strong></h2><h2><strong>I. Tổng hợp cấu trúc make và cách dùng trong tiếng Anh</strong></h2><h3><i><strong>1. Cấu trúc Make + somebody + do sth (Sai khiến ai đó làm gì)</strong></i></h3><p>Ví dụ:</p><ul><li>He <strong>makes her do</strong> all the housework. (Anh ta bắt cô ấy làm hết việc nhà)</li><li>The teacher <strong>makes her students go</strong> to school early. (Giáo viên bắt học sinh của mình đi học sớm).</li></ul><p>Đây là một cấu trúc sai khiến phổ biến. Nó thường được sử dụng trong giao tiếp cũng như trong các đề thi.</p><p>Những cấu trúc đồng nghĩa với cấu trúc với make:</p><ul><li><i>Get sb to do st</i></li><li><i>Have sb do sth</i></li></ul><p>Ví dụ:&nbsp;</p><ul><li>I make Peter fix my car&nbsp; (Tôi bắt Peter sửa ô tô cho tôi)</li></ul><p>=&gt; I’ll have Peter fix my car.</p><p>=&gt; I’ll get Peter to fix my car.</p><figure class="image"><img src="https://lh6.googleusercontent.com/Ik5u7y6Lv6qgTS-_Ycf54s9KaYkEdh-G9s1RmmrQyydwu30JisIm2qkBtph4yZMyaagmVO_f9FOzCja0j8kPVb05DnyvgtnVM4wC1ckAK36UNb6wDowdnVwuO-aImNxdaD3PjBPS=s0"></figure><h3><i><strong>2. Cấu trúc Make + somebody + to verb (buộc phải làm gì)</strong></i></h3><p>Ví dụ:</p><ul><li>Don’t make me cry. (Đừng làm tôi khóc.)</li><li>She makes me go out. (Cô ấy bắt tôi ra ngoài.)</li></ul><p>Cấu trúc này thường ở dạng bị động chuyển thể từ cấu trúc trên. Khi muốn sai khiến ai đó làm gì ở thể chủ động, ta dùng cấu trúc “Make sb do sth”. Trong câu bị động, sử dụng dùng cấu trúc “Make sb to do sth”.</p><p>Ví dụ:</p><ul><li>My teacher <strong>makes me </strong>do homework. (Giáo viên của tôi bắt tôi làm bài tập.)</li></ul><p>=&gt; I <strong>am made</strong> to do homework . (Tôi bị buộc phải làm bài tập).</p><ul><li>Nam <strong>makes his girlfriend be</strong> at home after wedding. (Hùng bắt bạn gái ở nhà sau khi cưới).</li></ul><p>=&gt; Nam’s girlfriend<strong> is made to be</strong> at home after wedding. (Bạn gái của Nam buộc phải ở nhà sau khi cưới.)</p><figure class="image"><img src="https://lh6.googleusercontent.com/qlnAiRTf0SV1w9pHMcM-7JCzJNQWAYQhTYa4I7Peb0WhT2NVy5Nvw1NltpdPiQhJPdN519iibrKmOkEe29M96y6JOLwWZOM4kBza6rVrlTeL_m1sGI3JzUsjenc6zv5ldKD5JqH2=s0" alt="Cấu trúc make trong tiếng Anh"></figure><h3><i><strong>3. Cấu trúc Make + sb/sth + adj (làm cho)</strong></i></h3><p>Trong giao tiếp tiếng Anh, người ta thường sử dụng cấu trúc này.</p><p>Ví dụ:</p><ul><li>The film makes me sad. (Bộ phim làm tôi buồn)</li><li>He makes me happy. (Anh ấy làm tôi hạnh phúc)</li><li>His gift makes me very happy. (Món quà của cô ấy làm tôi rất hạnh phúc)</li></ul><figure class="image"><img src="https://lh5.googleusercontent.com/Q-SLBETB2Jq86OWLF-Rw-mWTXtXIEqS8Ina5cnXlSrnNMqlXFl5AZeAsQQym_RbZGg-KZPKOLxb1xhDhX-dJSyGbbol_YSMz59I02Ei4M1fvPcIdTuPzfr6yzIY06B8taL5Dd2Da=s0"></figure><h3><i><strong>4. Cấu trúc Make + possible/ impossible</strong></i></h3><p>a. Cấu trúc<i><strong> Make it possible/impossible (for sb) + to V</strong></i></p><p>Nếu trong câu theo sau “make” là “to V” thì phải thêm “it” đứng giữa “make” và possible/impossible.</p><p>&nbsp;Phân tích câu dưới đây:</p><p>The new motorbike makes possible to go to school easily and quickly.</p><p>=&gt; Ta thấy theo sau make có to V (to go), vì vậy ta phải thêm it vào giữa make và possible.</p><p>=&gt; Vì vậy câu đúng phải là: The new motorbike makes it possible to go to school easily and quickly.</p><p>Ngoài ra, ở cấu trúc trên, bạn cũng có thể thay từ possible/ impossible bằng các từ khác như difficult, easy…</p><p>Ví dụ: Studying abroad makes it easier for me to settle down here. (Học ở nước ngoài giúp tôi định cư ở đây dễ dàng hơn).</p><p>b. Cấu trúc <strong>Make possible/ impossible + N/ cụm N</strong></p><p>Cấu trúc này ngược lại hoàn toàn với cấu trúc make possible ở trên.</p><p>Nếu theo sau make là một danh từ hoặc cụm danh từ thì “tuyệt đối” không đặt it ở giữa make và possible/impossible.</p><p>Ví dụ:</p><ul><li>The Internet makes possible much faster communication. (Internet giúp giao tiếp nhanh hơn).</li></ul><p>=&gt; “faster communication” là một cụm danh từ nên ta dùng make possible.</p><h2><strong>II. Những cụm từ đi với make thông dụng</strong></h2><p>Trong giải bài tập hay giao tiếp tiếng Anh hàng ngày, chúng ta sẽ bắt gặp nhiều cụm từ đi với make. Dưới đây là một số cụm từ và cụm động từ đi với make thông dụng.</p><h3><strong>1</strong><i><strong>. Cụm động từ với make</strong></i></h3><figure class="table"><table><tbody><tr><td>Make off&nbsp;</td><td>Chạy trốn</td></tr><tr><td>Make up for</td><td>Đền bù</td></tr><tr><td>Make up with sb</td><td>Làm hòa với ai</td></tr><tr><td>Make up</td><td>Trang điểm</td></tr><tr><td>Make out</td><td>Hiểu ra</td></tr><tr><td>Make for</td><td>Di chuyển về hướng</td></tr><tr><td>Make sth out to be&nbsp;</td><td>Khẳng định</td></tr><tr><td>Make over&nbsp;</td><td>Giao lại cái gì cho ai</td></tr><tr><td>Make sth out to be&nbsp;</td><td>Khẳng định</td></tr><tr><td>Make into&nbsp;</td><td>Biến đổi thành cái gì</td></tr></tbody></table></figure><p>&nbsp;</p><figure class="image"><img src="https://lh3.googleusercontent.com/1b1yo6Nzwn55S5jJ4Dx7nRKoZUvzRHZqmE1I_qCwlQ7uFenCjm7jpnBvGt-HzPSjHr22caQ_a91__PBkrGhGYaHxnv6b4eXWALhVvmd0IPkGPcXfIlQE1CenVtC_y_UphydZ41sR=s0" alt="Cụm động từ với make"></figure><h3><i><strong>2. Cụm từ (collocations) với “make”</strong></i></h3><figure class="table"><table><tbody><tr><td>Make a decision = make up one’s mind&nbsp;</td><td>Quyết định</td></tr><tr><td>Make an impression on sb</td><td>Gây ấn tượng với ai</td></tr><tr><td>Make a living</td><td>Kiếm sống</td></tr><tr><td>Make a bed</td><td>Dọn dẹp giường</td></tr><tr><td>Make a fuss over sth</td><td>Làm rối, làm ầm lên</td></tr><tr><td>Make friend with sb&nbsp;</td><td>Kết bạn với ai</td></tr><tr><td>Make the most/the best of sth</td><td>Tận dụng triệt để</td></tr><tr><td>make progress</td><td>Tiến bộ</td></tr><tr><td>make a contribution to&nbsp;</td><td>Góp phần</td></tr><tr><td>make a habit of sth</td><td>Tạo thói quen làm gì</td></tr><tr><td>make money&nbsp;</td><td>Kiếm tiền</td></tr><tr><td>make an effort&nbsp;</td><td>Nỗ lực</td></tr><tr><td>make way for sb/sth&nbsp;</td><td>Dọn đường cho ai, cái gì&nbsp;&nbsp;&nbsp;</td></tr></tbody></table></figure>	 	2023-06-29 09:50:26.053	2023-06-29 09:50:26.053
332	218	1	Câu hỏi về chủ đề, mục đích	1	https://www.youtube.com/watch?v=WVoJE6Qijkc&ab_channel=STUDY4	0	0		 Câu hỏi về chủ đề, mục đích\n1. Đặc điểm chung\nCâu hỏi về chủ đề, mục đích hỏi về nội dung chính, lý do mà văn bản được viết. Dạng câu hỏi này thường xuất hiện ở dạng bài Announcement/ Notice (Thông báo), Email/ Letter (Thư), Article (Bài báo). \nCâu hỏi chủ đề, mục đích Part 7 thường có dạng: \nWhat is the purpose of the announcement/ the first email…?\nWhat is one purpose of the notice/ the advertisement…? \nWhy did Mr. Smith send the e-mail?\nWhy most likely was the article/ the letter… written? \n=> Các câu trả lời đều có dạng to V. \n\nCâu hỏi chủ đề, mục đích thường là câu hỏi đầu tiên của một đoạn văn bản. Thông tin chứa đáp án có khi nằm ở ngay câu đầu, có khi dàn trải trong toàn bộ văn bản. \nDạng câu hỏi này chiếm từ 3-5/ 54 câu hỏi của Part 7. \n2. Phân tích ví dụ\n2.1. Đối với đoạn văn bản ngắn, ít câu hỏi\nExample 1\n(ETS 2022 - Test 1 - Q147)\n\nhttp://www.moonglowairways.com.au\n\nSpecial Announcement by Geoff Clifford, President of Moon Glow Airways\n\nAs many of you are aware, there was a problem with Pelman Technology, the system that handles our airline reservations. This outage has affected several airlines. It's been a rough week, but the good news is that it has been repaired, and we are re-setting our system. However, Moon Glow passengers may still face delays for a day or two. This most likely will include longer lines at airports. We have added more on-site customer service representatives at airports in all of our destination cities to assist customers with their flights and information. We appreciate your understanding and patience.\n\n=> Hình thức: Announcement (Thông báo)\n\nĐọc câu hỏi: Xác định dạng câu hỏi và nhớ ý chính 4 đáp án \nQ: What is the purpose of the announcement? => Dạng câu hỏi chủ đề, mục đích\n\nMục đích của thông báo là gì?                            \n\n(A) To report on airport renovations\n\n      Thông báo việc cải tạo sân bay\n\n(B) To give an update on a technical problem\n\n      Cập nhật một vấn đề kỹ thuật\n\n(C) To introduce a new reservation system\n\n      Giới thiệu hệ thống đặt chỗ mới \n\n(D) To advertise airline routes to some new cities\n\n      Quảng cáo đường bay tới những thành phố mới\n\nTìm thông tin + chọn đáp án: \nChủ đề của dạng văn bản Announcement thường xuất hiện ở câu đầu tiên và câu cuối (nếu có) cũng sẽ nói lên mục đích của văn bản.   \n\nĐọc câu đầu và câu cuối:\n\nAs many of you are aware, there was a problem with Pelman Technology, the system that handles our airline reservations. => Thông báo về vấn đề với hệ thống đặt chỗ. => lỗi kỹ thuật\nWe appreciate your understanding and patience => câu kết thường xuất hiện trong những văn bản thông báo vấn đề, cáo lỗi. \n=> Nội dung chính: thông báo về một lỗi kỹ thuật => dự đoán là đáp án (B)\n\nĐọc thêm thông tin sau câu đầu để chắc chắn hơn: \n\nbut the good news is that it has been repaired, and we are re-setting our system. => cập nhật thông tin nó đã được sửa và đang thiết lập lại hệ thống. \n=> Nội dung chính: cập nhật về một lỗi kỹ thuật\n\n=> Đáp án (B)\n\nLưu ý 1: Một số cụm/ mệnh đề là cách liên kết ý phổ biến: cụm mở đầu As many of you are aware (Như quý vị đã biết) để thông báo tin tức, tiếp đó là but the good news is that (nhưng tin tốt là) để cập nhật tin mới (tin tốt). Kết thúc văn bản là câu We appreciate your understanding and patience. (Chúng tôi trân trọng sự thấu hiểu và kiên nhẫn của quý vị), thường xuất hiện trong những văn bản thông báo vấn đề, cáo lỗi. \n\n=> Các cụm/ mệnh đề này không chứa thông tin chính nhưng dựa vào nó ta cũng sẽ khoanh vùng được đáp án\n\nLưu ý 2: Về thứ tự làm bài: đoạn văn này gồm 2 câu hỏi: câu hỏi về chủ đề, mục đích và câu hỏi về chi tiết, tìm thông tin. Câu thứ 2 lấy thông tin ở nửa sau của văn bản => nên làm bài theo thứ tự, tức là làm câu hỏi chủ đề, mục đích trước. \n\nExample 2:\n(ETS 2022 - Test 1 - Q188)\n\nAttention, Seminar Participants:\n\nUnfortunately, we do not have copies of Emilio Costa's book Branding Strategies in Graphic Design with us today. For those of you who have ordered it, please give your mailing address to the volunteer at the check-in desk, and the book will be mailed to your home at no cost to you. We will charge your credit card upon shipment. We are sorry for the inconvenience.\n\n=> Hình thức: Notice (Thông báo)\n\nĐọc câu hỏi:\nQ: What is the purpose of the notice? => Câu hỏi chủ đề, mục đích\n\nMục đích của thông báo là gì?\n\n(A) To explain a problem\n\n      Giải thích một vấn đề\n\n(B) To ask for volunteers\n\n      Kêu gọi tình nguyện viên\n\n(C) To request payment\n\n      Yêu cầu thanh toán\n\n(D) To promote a book\n\n      Quảng bá một cuốn sách\n\nTìm thông tin + chọn đáp án: \nĐoạn rất ngắn nên có thể đọc rất nhanh và xác định ý chính. Các thông tin quan trọng là: \n\nwe do not have copies of …with us today. => Không có sách => Thông báo vấn đề\nFor those of you who have ordered it, please give your mailing address,...the book will be mailed to your home… => Ai đã đặt sách để lại địa chỉ để sách gửi đến nhà => Hướng giải quyết\nWe are sorry for the inconvenience. => lời xin lỗi, kết lại thông báo về sự cố\n=> Nội dung chính: Thông báo một vấn đề phát sinh và hướng giải quyết\n\n=> Đáp án (A) \n\nLưu ý 1: Mở đầu và kết thúc của thông báo là Unfortunately (Thật không may) và We are sorry for the inconvenience (Chúng tôi xin lỗi vì sự bất tiện này) là từ và câu xuất hiện trong văn bản thông báo về vấn đề không may phát sinh. Đây cũng là yếu tố có thể giúp dự đoán được đáp án là (A).  \n\nLưu ý 2: Đoạn văn bản này là đoạn thứ 2 trong cụm 3 đoạn 5 câu hỏi. Trước và sau chiếc notice ngắn là 2 email khá dài. Liên quan đến đoạn này chỉ có 1 câu hỏi như trên. \n\n=> Trước khi làm, các bạn nên xem lướt 1 lượt 3 đoạn, nếu thấy xuất hiện đoạn văn ngắn => chọn làm trước. \n\n2.2. Đối với đoạn văn bản dài, nhiều câu hỏi\n(ETS 2022 - Test 1 - Q168)\n\nMarch 29\n\nDr. Maritza Geerlings\n\nPoseidon Straat 392\n\nParamaribo\n\nSuriname\n\nDear Dr. Geerlings,\n\nI am writing to thank you for your years of service on the faculty of the Jamaican Agricultural Training Academy (JATA) and to let you know about some exciting developments. As you know, JATA was originally established as a vocational school for agriculture but now offers courses in a varied array of disciplines, including cybersecurity, electrical engineering, and health information management. Our student body, which for the first ten years consisted almost exclusively of locals, is now culturally diverse, with students from across the Americas and Europe. Today's students work with sophisticated equipment, much of which did not exist in our early days.\n\nTo reflect these and other significant changes that JATA has undergone over time, the Board of Trustees has approved a proposal by the Faculty Senate to rename the institution the Caribbean Academy of Science and Technology. As a result, a new institutional logo will be adopted. All students and faculty members, both current and former, are invited to participate in a logo design contest. Information about the contest will be forthcoming.\n\nThe renaming ceremony and the introduction of the new logo will take place at 11 A.M. on 1 June, the twentieth anniversary of the institution. We hope you will be able to join us.\n\nSincerely,\n\nAudley Bartlett\n\nVice President for Academic Affairs,\n\nJamaican Agricultural Training Academy\n\n=> Hình thức: Letter (Thư tay)\n\nĐọc câu hỏi: \nWhat is one purpose of the letter? => Câu hỏi chủ đề, mục đích\n\n     Một trong những mục đích của bức thư là gì?\n\n(A) To announce a name change.\n\n     Để thông báo thay đổi tên.\n\n(B) To honor distinguished alumni.\n\n     Để vinh danh cựu sinh viên tiêu biểu.\n\n(C) To suggest revisions to a curriculum.\n\n     Để đề xuất sửa đổi một chương trình giảng dạy.\n\n(D) To list an individual's accomplishments.\n\n     Để kể ra những thành tựu của một cá nhân.\n\n=> Lưu ý câu hỏi về một mục đích => thư sẽ có nhiều mục đích\n\nTìm thông tin + chọn đáp án:\nMục đích của dạng văn bản Letter (Thư tay) thường xuất hiện ở câu đầu.\n=> 2 mục đích: \n\nthank you for your years of service on the faculty of the Jamaican Agricultural Training Academy (JATA) => cảm ơn nhân viên \n to let you know about some exciting developments  => thông báo về những sự phát triển mới. \n=> Đối chiếu các đáp án: \n\nCâu (A): có thể là exciting development\nCâu (B): nói về sinh viên, không phải giảng viên => Loại\nCâu (C): mới chỉ là gợi ý, chưa phải development => Loại\nCâu (D): có thể xuất hiện nhưng không phải mục đích chính khi muốn tri ân giảng viên hay thông báo về sự phát triển mới. => Loại\n=> Dự đoán đáp án là (A) \n\n-  Scan thông tin về name change để chắc chắn hơn:  ta thấy thông tin xuất hiện ở đoạn 2 với từ khóa rename: To reflect these and other significant changes that JATA has undergone over time, The Board of Trustees has approved a proposal by the Faculty Senate to rename the institution the Caribbean Academy of Science and Technology => đề xuất đổi tên đã được phê duyệt \n\n=> Đáp án (A) \n\nLưu ý 1: Cách mở đầu thư phổ biến nhất: I am writing to… nói về mục đích viết thư. Tuy nhiên, phần này có thể chỉ đưa ra mục đích khái quát, chung chung, còn thông tin cụ thể cần đọc thêm phía sau. Nếu thư có nhiều hơn một đoạn thì có thể nội dung chính sẽ nằm ở đoạn sau. \n\nLưu ý 2: Về thứ tự làm bài: Đoạn văn có 5 câu hỏi liên quan. Cụ thể:\n\nQ1: What is one purpose of the letter?\n\nA. To announce a name change\n\nB. To honor distinguished alumni\n\nC. To suggest revisions to a curriculum\n\nD. To list an individual's accomplishments\n\n=> Câu hỏi chủ đề, mục đích\n\nQ2: The word "established" in paragraph 1, line 3, is closest in meaning to\n\nA. affected\n\nB. founded\n\nC. confirmed\n\nD. settled\n\n=> Câu hỏi tìm từ đồng nghĩa\n\nQ3: What is suggested about Dr. Geerlings?\n\nA. She plans to attend JATA's anniversary celebration.\n\nB. She has taught courses in cybersecurity,\n\nC. She can take part in JATA's logo design contest.\n\nD. She served on JATA's Board of Trustees.\n\n=> Câu hỏi suy luận\n\nQ4: What is NOT indicated about JATA in the letter?\n\nA. Its professors live on campus.\n\nB. Its students have access to modern equipment.\n\nC. It will be twenty years old on June 1.\n\nD. It is attended by international students.\n\n=> Câu hỏi tìm chi tiết sai \n\n=> Ta có thể làm bài theo thứ tự: 2, 3, 4, 1\n\nLàm các câu hỏi tìm thông tin trước rồi làm câu hỏi về chủ đề tổng quát sau, vì khi đó ta đã đọc gần hết các chi tiết trong bài. 	2023-06-29 10:02:05.759	2023-06-29 10:02:05.759
304	202	2	Luyện nghe với flashcard phần 2	3		0	24		 	2023-06-29 08:59:59.984	2023-06-29 08:59:59.984
328	214	1	Giới thiệu về bảng kí hiệu ngữ âm quốc tế (IPA)	1	https://www.youtube.com/watch?v=n4NVPg2kHv4&ab_channel=mmmEnglish	0	0		 Bảng phiên âm tiếng Anh quốc tế (International Phonetic Alphabet - viết tắt là IPA) có tổng cộng 44 âm chính bao gồm 20 nguyên âm (vowel sounds) và 24 phụ âm (consonant sounds). Tùy theo mỗi âm, bạn sẽ phải luyện phát âm tiếng Anh với 44 âm tương ứng. \n\n\n\n1. Nguyên âm (Vowel sounds)\n\nKhi học cách phát âm 44 âm trong tiếng Anh, bạn phải nhận biết được 20 cách đọc nguyên âm chính được viết như sau:  /ɪ/, /i:/, /ʌ/, /ɑ:/, /æ/, /e/, /ə/, /ɜ:/, /ɒ/, /ɔ:/, /ʊ/, /u:/, /aɪ/, /aʊ/, /eɪ/, /oʊ/, /ɔɪ/, /eə/, /ɪə/, /ʊə/. \n\n2. Phụ âm (Consonants)\n\nHọc cách phát âm 44 âm trong tiếng anh bao gồm cả phụ âm và nguyên âm. Đối với phụ âm, bạn phải nhận biết được 24 cách đọc chủ yếu: /p/, /b/, /d/, /f/, /g/, /h/, /j/, /k/, /l/, /m/, /n/, /ŋ/, /r/, /s/, /ʃ/, /t/, /tʃ/, /θ/, /ð/, /v/, /w/, /z/, /ʒ/, /dʒ/. \n\n- Monothongs: âm đơn\n\n- Diphthongs: âm đôi \n\n- Voiceless sounds: âm vô thanh là những âm được phát ra nhưng không tạo độ rung từ thanh quản. Thường chúng chỉ tạo ra hơi gió, tiếng xì hoặc tiếng bật vì âm được tạo ra từ luồng không khí trong khoang miệng chứ không phải từ thanh quản.\n\n- Voiced sounds: âm hữu thanh là những âm sẽ làm rung thanh quản khi phát âm (bạn có thể kiểm tra bằng cách đưa tay sờ lên thanh quản).	2023-06-29 09:52:12.701	2023-06-29 09:52:12.701
333	219	1	TOEIC là gì? Tại sao lại phải học và thi TOEIC?	2		0	0	<h2><strong>TOEIC là gì? Tại sao lại phải học và thi TOEIC?</strong></h2><p><strong>TOEIC</strong> (viết tắt của <i>Test of English for International Communication</i> – <i>Bài kiểm tra tiếng Anh giao tiếp&nbsp;quốc tế</i>) là một bài thi nhằm đánh giá trình độ sử dụng tiếng Anh dành cho những người sử dụng tiếng Anh như một ngoại ngữ (không phải tiếng mẹ đẻ), đặc biệt là những đối tượng muốn <strong>sử dụng tiếng Anh trong môi trường giao tiếp và làm việc quốc tế</strong>. Kết quả của bài thi TOEIC phản ánh mức độ thành thạo khi giao tiếp bằng tiếng Anh trong các hoạt động như kinh doanh, thương mại, du lịch… Kết quả này có&nbsp;<strong>hiệu lực trong vòng 02 năm</strong>&nbsp;và được công nhận tại nhiều quốc gia trong đó có Việt Nam.</p><figure class="image"><img src="https://cla.hust.edu.vn/xmedia/2013/12/english-test-key.jpg" alt="English Test Key" srcset="https://cla.hust.edu.vn/xmedia/2013/12/english-test-key.jpg 730w, https://cla.hust.edu.vn/xmedia/2013/12/english-test-key-300x98.jpg 300w, https://cla.hust.edu.vn/xmedia/2013/12/english-test-key-450x147.jpg 450w, https://cla.hust.edu.vn/xmedia/2013/12/english-test-key-532x175.jpg 532w" sizes="100vw" width="730"></figure><h3>Lịch sử hình thành</h3><p>Chương trình thi TOEIC được xây dựng và phát triển bởi&nbsp;Viện Khảo thí Giáo dục (ETS – Educational Testing Service), Hoa Kỳ – một tổ chức nổi tiếng và uy tín chuyên cung cấp các chương trình kiểm tra trắc nghiệm như TOEFL, GRE, GMAT… theo đề nghị từ Liên đoàn Tổ chức Kinh tế Nhật Bản (Keidanren) kết hợp với Bộ Công thương Quốc tế Nhật Bản – MITI (nay là Bộ Kinh tế, Thương mại và Công nghiệp Nhật Bản – METI) vào năm 1979.&nbsp;&nbsp;Bài thi TOEIC được thiết kế dựa trên cơ sở tiền thân của nó là chương trình trắc nghiệm TOEFL.&nbsp;Và tính đến nay, sau hơn 35&nbsp;năm, ETS đã tổ chức kiểm tra cho nhiều triệu lượt người tham dự trên khắp thế giới. Ở Việt Nam, TOEIC bắt đầu được tổ chức thi từ năm 2001 thông qua đại&nbsp;diện là IIG Việt Nam, được ưa thích và phổ biến rộng rãi hơn khoảng 5 năm sau đó.</p><h3>TOEIC dùng để làm gì?</h3><p>Trước đây tại Việt Nam, nhiều công ty, doanh nghiệp, tổ chức…&nbsp;thường sử dụng chứng chỉ tiếng Anh phân chia theo cấp độ A, B, C (chứng chỉ ABC) như một tiêu chí ngoại ngữ để đưa ra quyết định về tuyển dụng, bổ nhiệm, sắp xếp nhân sự&nbsp;hay bố trí nhân viên tu nghiệp tại nước ngoài.&nbsp;Tuy nhiên trong khoảng 07 năm trở lại đây, chứng chỉ TOEIC nổi lên như một tiêu chuẩn phổ biến hơn để đánh giá trình độ thông thạo tiếng Anh của người lao động.</p><figure class="image"><img src="https://cla.hust.edu.vn/xmedia/2013/12/test-english.png" alt="Test English" srcset="https://cla.hust.edu.vn/xmedia/2013/12/test-english.png 624w, https://cla.hust.edu.vn/xmedia/2013/12/test-english-300x112.png 300w, https://cla.hust.edu.vn/xmedia/2013/12/test-english-450x168.png 450w, https://cla.hust.edu.vn/xmedia/2013/12/test-english-466x175.png 466w" sizes="100vw" width="624"></figure><p>Xuất phát từ thực tế đó, nhiều trường Đại học, Cao đẳng đã đưa TOEIC vào chương trình giảng dạy và lựa chọn bài thi TOEIC để theo dõi&nbsp;sự tiến bộ trong việc học tiếng Anh đối với sinh viên theo từng học kỳ, năm học hoặc sử dụng làm chuẩn đầu ra tiếng Anh cho sinh viên tốt nghiệp. Chính vì những lý do đó nên việc&nbsp;<strong>học TOEIC</strong>,&nbsp;<strong>luyện thi TOEIC</strong>&nbsp;và tham dự&nbsp;<strong>kỳ thi TOEIC</strong>&nbsp;đóng vai trò quan trọng trong việc chuẩn bị hành trang kiến thức&nbsp;với nhiều sinh viên và người đi làm.</p><h3>Cấu trúc của bài thi TOEIC</h3><p>Bài thi TOEIC truyền thống là một bài kiểm tra trắc nghiệm bao gồm 02 phần:&nbsp;<strong>phần thi Listening</strong>&nbsp;(nghe hiểu) gồm 100 câu, thực hiện trong 45 phút và&nbsp;<strong>phần thi Reading</strong>&nbsp;(đọc hiểu) cũng gồm 100 câu nhưng thực hiện trong 75 phút. Tổng thời gian làm bài là 120 phút (2 tiếng).</p><ul><li><strong>Phần thi Nghe hiểu</strong>&nbsp;<i>(100 câu / 45 phút)</i>: Gồm 4 phần nhỏ được đánh số từ&nbsp;<i><strong>Part&nbsp;1</strong></i>&nbsp;đến&nbsp;<i><strong>Part&nbsp;4</strong></i>. Thí sinh phải&nbsp;lần lượt&nbsp;lắng nghe các đoạn hội thoại ngắn, các đoạn thông tin, các câu hỏi với các ngữ âm khác nhau như: Anh – Mỹ, Anh – Anh, Anh – Canada &amp; Anh – Úc để trả lời.</li><li><strong>Phần thi Đọc hiểu</strong>&nbsp;<i>(100 câu / 75 phút)</i>: Gồm 3 phần nhỏ được đánh số từ&nbsp;<i><strong>Part 5</strong></i>&nbsp;đến&nbsp;<i><strong>Part 7</strong></i>&nbsp;tương ứng với 3 loại là câu chưa hoàn chỉnh, nhận ra lỗi sai và đọc hiểu các đoạn thông tin. Thí sinh&nbsp;<strong>không nhất thiết phải làm tuần tự</strong>&nbsp;mà có thể chọn câu bất kỳ để làm trước.</li></ul><p>Mỗi câu hỏi đều cung cấp&nbsp;<strong>4 phương án trả lời A-B-C-D</strong>&nbsp;<i>(trừ các câu từ 11-40 của part 2 chỉ có 3 phương án trả lời A-B-C)</i>. Nhiệm vụ của thí sinh là phải chọn ra phương án trả lời đúng nhất và dùng bút chì để tô đậm ô đáp án&nbsp;của mình. Bài thi TOEIC không đòi hỏi kiến thức và vốn từ vựng chuyên ngành mà chỉ tập trung với các ngôn từ sử dụng trong công việc và giao tiếp hàng ngày. Chi tiết về nội dung của từng phần thi có thể tham khảo tại đây &gt;&gt;&nbsp;<a href="https://cla.hust.edu.vn/toeic/cau-truc-de-thi-toeic/">https://cla.hust.edu.vn/toeic/cau-truc-de-thi-toeic/</a></p><h3>Bài thi TOEIC Speaking &amp; Writing</h3><p>Ngoài bài thi TOEIC truyền thống (Listening &amp; Reading), bạn có thể tham dự thêm bài thi TOEIC Speaking (Nói) &amp; Writing (Viết) để có thể đáp ứng cả 4 kỹ năng Nghe – Nói – Đọc – Viết mà nhiều vị trí ứng tuyển đòi hỏi. Bạn cũng cần lưu ý: Theo khuyến nghị của ETS, nếu đạt trên 500 điểm với bài thi TOEIC Listening &amp; Reading thì bạn nên tham dự cả bài thi TOEIC Speaking &amp; Writing để đánh giá đầy đủ cả 2 kỹ năng Nói &amp; Viết. Điểm số của bài thi này&nbsp;được chia ra các cấp độ khác nhau được gọi là “các cấp độ thành thạo” (proficiency levels) chứ không dùng thang điểm như bài thi TOEIC Listening &amp; Reading.</p><h3>Điểm thi TOEIC &amp; cách tính điểm bài thi</h3><figure class="image"><img src="https://cla.hust.edu.vn/xmedia/2013/12/toeic-certificate.jpg" alt="TOEIC Certificate" srcset="https://cla.hust.edu.vn/xmedia/2013/12/toeic-certificate.jpg 1632w, https://cla.hust.edu.vn/xmedia/2013/12/toeic-certificate-300x225.jpg 300w, https://cla.hust.edu.vn/xmedia/2013/12/toeic-certificate-450x337.jpg 450w, https://cla.hust.edu.vn/xmedia/2013/12/toeic-certificate-233x175.jpg 233w" sizes="100vw" width="1632"></figure><p>Điểm của bài thi TOEIC được tính và quy đổi dựa trên số câu trả lời đúng, bao gồm hai điểm độc lập: điểm của phần thi Nghe hiểu và điểm của phần thi Đọc hiểu. Bắt đầu từ 5, 10, 15… cho tới&nbsp;<strong>495 điểm</strong>&nbsp;mỗi phần. Tổng điểm của cả 2 phần thi sẽ có thang&nbsp;<strong>từ 10 đến 990 điểm</strong>. Sau khi có kết quả, thí sinh sẽ nhận được chứng chỉ TOEIC (phiếu điểm) được gửi riêng cho từng thí sinh (không công bố công khai). Việc quy đổi điểm số từ số câu trả lời đúng có thể tham khảo tại đây &gt;&gt;&nbsp;<a href="https://cla.hust.edu.vn/toeic/thang-diem-va-cach-tinh-diem-bai-thi-toeic/">https://cla.hust.edu.vn/toeic/thang-diem-va-cach-tinh-diem-bai-thi-toeic/</a></p><h3>Chuẩn TOEIC? Cần đạt bao nhiêu điểm TOEIC để được cấp chứng chỉ</h3><p>Cũng giống như bài thi IELTS, kết quả của bài thi TOEIC không có mức điểm để quy định đỗ hay trượt mà chỉ phản ánh trình độ sử dụng tiếng Anh của người tham dự. Tuy nhiên tại nhiều trường Đại học tại Việt Nam, đều có quy định chuẩn đầu ra tiếng Anh. Theo đó, sinh viên khi tốt nghiệp phải đạt chuẩn tiếng Anh tương đương với&nbsp;<strong>TOEIC 450</strong>&nbsp;hoặc cao hơn tùy theo chuyên ngành. Khi&nbsp;tham dự thi TOEIC bạn cũng cần lưu ý: Nếu muốn cung cấp thêm phiếu điểm để nộp Hồ sơ tuyển dụng cho&nbsp;các đơn vị tuyển dụng, thí sinh phải đạt&nbsp;<strong>điểm TOEIC từ 200 trở lên</strong>.<strong>&nbsp;</strong>Nếu muốn cung cấp thêm phiếu điểm để nộp Hồ sơ du học, thí sinh phải đạt&nbsp;<strong>điểm TOEIC từ 500 trở lên</strong>. Lệ phí cho mỗi phiếu điểm in thêm là&nbsp;<strong>50.000 đồng</strong>, nếu cần chuyển phát nhanh thì nộp thêm&nbsp;<strong>15.000 đồng</strong>.</p><h3>Một số mức điểm TOEIC tham khảo</h3><ul><li>TOEIC 100 –&nbsp;300 điểm: Trình độ cơ bản. Khả năng giao tiếp tiếng Anh kém.</li><li>TOEIC 300 – 450 điểm: Có khả năng hiểu &amp; giao tiếp tiếng Anh mức độ trung bình. Là yêu cầu đối với học viên tốt nghiệp các trường nghề, cử nhân các trường Cao đẳng (hệ đào tạo 3 năm).</li><li>TOEIC 450 – 650 điểm: Có khả năng giao tiếp tiếng Anh khá. Là yêu cầu chung đối với SV&nbsp;tốt nghiệp Đại học hệ đào tạo 4-5 năm; nhân viên, trưởng nhóm tại các doanh nghiệp có yếu tố nước ngoài.</li><li>TOEIC 650 – 850 điểm: Có khả năng giao tiếp tiếng Anh tốt. Là yêu cầu đối với cấp trưởng phòng, quản lý điều hành cao cấp, giám đốc trong môi trường làm việc quốc tế.</li><li>TOEIC 850 – 990 điểm: Có khả năng giao tiếp tiếng Anh rất tốt. Sử dụng gần như người bản ngữ dù tiếng Anh không phải tiếng mẹ đẻ.</li></ul><p><br>&nbsp;</p>	 	2023-06-29 10:04:25.58	2023-06-29 10:04:25.58
305	203	1	Dạng bài True/False/Not Given - Yes/No/Not Given	1	https://www.youtube.com/watch?v=6YLe63ssIIw&ab_channel=STUDY4	0	0		I. Tổng quan:\nDạng bài tập True/False/Not Given (hay Yes/No/Not Given) được đánh giá là một trong những dạng bài khó, đồng thời cũng khá thường gặp, trong IELTS Reading. \nCấu trúc (Structure) của dạng bài tập này sẽ bao gồm một văn bản cho trước cùng với một list các câu lệnh (statements).\nVì đây là một dạng bài tập khó và dễ gây nhầm lẫn, trước tiên chúng ta cần phân biệt sự khác nhau giữa bài tập True/False/Not Given và Yes/No/Not Given. \nTrue/False/Not Given vs Yes/No/Not Given\n\nYes/No/Not Given - Bài đọc sẽ bao gồm những ý kiến (opinion), quan điểm (view) và niềm tin (belief) của tác giả hoặc những người được nhắc đến trong bài.\nNhiệm vụ của người đọc ở dạng bài này là quyết định xem điều nào sau đây được áp dụng cho thông tin trong mỗi nhận định cho trước: \nYES (Y) - khi ý của phần nhận định trùng khớp với ý tác giả đưa ra trong bài.  \nNO (N) - khi ý của phần nhận định trái ngược với ý tác giả đưa ra trong bài. \nNOT GIVEN (NG) - khi thông tin không có trong bài đọc. \n  True/False/Not Given - Bài đọc sẽ bao gồm những thông tin thực tế (factual information) về một chủ đề nào đó. \nỞ dạng bài này, chúng ta sẽ điền: \n\nTRUE (T) - khi bài đọc có thông tin và khẳng định thông tin đó. \nFALSE (F) - khi bài đọc chứa thông tin trái ngược hoàn toàn.   \nNOT GIVEN (NG) - khi bài đọc không có thông tin hoặc không thể xác định được.                   \nLƯU Ý: Trước khi làm bài cần đọc kỹ yêu cầu của đề, tránh nhầm giữa T/F/NG và Y/N/NG\nII. The big challenge: \nBởi đây không chỉ là dạng bài kiểm tra khả năng xác định tính đúng/ sai của nhận định mà còn kiểm tra khả năng đọc hiểu và tìm kiếm thông tin của người đọc; vì vậy, trên thực tế, đây là một trong những dạng bài đọc khó nhất của IELTS Reading. \nThách thức lớn nhất ở dạng bài này, đối với những nhận định không có trong bài (Not Given), người đọc sẽ đi tìm những thông tin không có trong bài. Điều này dễ dẫn đến việc mất nhiều thời gian trong việc đọc lại nhiều lần văn bản để kiểm tra lại thông tin. \nThách thức thứ hai nằm ở việc nếu không chuẩn bị và luyện tập kĩ dạng bài này, người đọc sẽ dễ nhầm lẫn giữa những câu trả lời False (hoặc No) với những câu Not Given.\nVậy làm sao để vượt qua được những thách thức trên? \n\nCâu trả lời sẽ nằm ở phần chiến thuật (the strategy) và các mẹo (tips) làm bài dưới đây.\nIII. Phương pháp làm bài: \nStep 1: Đọc kỹ đề bài. Xem kỹ yêu cầu điền Yes/No/Not Given hay True/False/Not Given \nStep 2: Trước khi đọc bài đọc, hãy đọc list các nhận định cho trước và cố gắng hiểu nội dung của các nhận định. Việc này giúp chúng ta hình thành những phỏng đoán về nội dung của bài đọc, từ đó việc tìm kiếm thông tin sẽ trở nên nhanh chóng và hiệu quả hơn.  \nStep 3: Vì các nhận định thường sẽ được được viết khác đi so với trong bài đọc, ta nên suy nghĩ trước về các từ đồng nghĩa có thể xuất hiện trong bài và lưu ý những từ giới hạn nghĩa của câu (qualifying words), chẳng hạn như all, some, always, often, ... \nStep 4: Gạch chân từ khóa. Tuy những từ khóa này sẽ không giống hoàn toàn như trong văn bản nhưng điều này sẽ giúp chúng ta nhạy bén hơn trong việc việc tìm từ đồng nghĩa cũng như xác định thông tin trong văn bản. \nStep 5: Bắt đầu đọc lướt văn bản để xác định vị trí của các nhận định theo thứ tự (việc này chủ yếu dựa vào các từ khóa và từ đồng nghĩa). Sau khi đã xác định được vị trí câu trả lời, chúng ta bắt đầu đọc một cách chi tiết để xác định mối tương quan giữa thông tin trong bài và các nhận định. \nStep 6: Đưa ra câu trả lời dựa trên: \nYES/TRUE - Nếu quan điểm hoặc thông tin trong bài hoàn toàn trùng khớp với nhận định  (tuy từ ngữ, cách diễn đạt có thể khác) \nNO/FALSE - Ngược lại\nNOT GIVEN - Nếu ta không thể tìm thấy thông tin của nhận định sau khi đọc bài đọc thì khả năng cao thông tin đó không được đưa ra trong bài. \nStep 7: Lặp lại các bước trên cho đến khi hoàn thành bài. \nIV. Một số mẹo làm bài: \nCác câu trả lời sẽ xuất hiện theo thứ tự trong văn bản giống như thứ tự của các nhận định cho trước. Vì vậy, ta không cần lãng phí thời gian đọc lại từ đầu để tìm câu trả lời. Thay vào đó, ta chỉ cần tiếp tục đọc phần còn lại của bài. \nKhông cần thiết phải đọc toàn bộ bài đọc. Ta chỉ cần gạch chân từ khóa và dùng kĩ năng đọc lướt (skimming) để xác định chúng trong bài. Sau đó, ta sẽ đọc kỹ để tìm ra câu trả lời. \nThông thường sẽ có ít nhất một trong mỗi loại câu trả lời - Yes, No, Not Given. Vì vậy, nếu không có ít nhất một trong số mỗi khi hoàn thành câu hỏi, khả năng cao chúng ta đã làm sai ở đâu đó.\nĐề phòng những từ gây nhiễu (distractors). Ví dụ điển hình của phần này là những từ giới hạn nghĩa của câu (qualifying words) vì chỉ cần thay đổi một từ sẽ dẫn đến câu có nghĩa khác hoàn toàn. \n  every                       a few\n\n   always                     occasionally\n\n   some                       most\n\n   majority                    all\n\nExample: \n\nTom always visits his grandparents on the weekend. \nTom occasionally visits his grandparents on the weekend. \nLưu ý: Ở dạng bài tập này, nghĩa của câu phải trùng khớp chính xác với thông tin trong bài thì câu trả lời mới là YES/TRUE\nNgoài ra, ta cũng cần lưu ý những từ chỉ khả năng hoặc sự nghi ngờ như: \n    seem                claim\n\n   suggest            possibly\n\n   believe             probably\n\nGiống như lưu ý trên, những từ này có thể làm thay đổi nghĩa của câu. \n\nExample: \n\nThe police claimed that he was the culprit. \nThe police believed that he was the culprit. \nCác nhận định cho trước sẽ không giống 100% thông tin đưa ra trong bài, chúng có thể bao gồm các từ đồng nghĩa và cách diễn đạt khác vì vậy ta cần chú ý phần này, gạch chân trước những keywords và brainstorm trước những từ đồng nghĩa có thể gặp trong bài.	2023-06-29 09:04:18.03	2023-06-29 09:04:18.03
329	215	1	Cách phát âm 'long a' /eɪ/	1	https://www.youtube.com/watch?v=0RXzfRcjk-s&ab_channel=SoundsAmerican	0	0		Ý chính cần nhớ:\n\n'Long a' / eɪ / là một nguyên âm có 2 âm. Nó là âm giữa trong từ 'cake' / keɪk /.\n\nCách phát âm: đọc âm / ɪ / rồi chuyển dần sang âm / ə /. Môi từ dẹt thành hình tròn dần. Lưỡi thụt dần về phía sau.\n\nChi tiết bài học:\n\nXin chào!\n\nĐây là kênh "Sounds American"\n\nTrong video này, chúng ta sẽ nói về nguyên âm /ei/ trong tiếng Mỹ giống như trong từ "make"\n\nChúng ta có thể nghe âm này trong các từ như\n\n"take," "day," "wait" hay "eight."\n\nChúng ta sẽ sử dụng - /ei/ - là ký hiệu phiên âm cho âm này.\n\nHãy làm một bài kiểm tra nhanh\n\nĐọc ngữ câu này thật to: mỗi từ trong thành phần câu này đều có âm /ei/\n\nNếu bạn không chắc phát âm đúng từ này, hãy tiếp tục xem nhé\n\nOK\n\nĐể phát âm /ei/ , bạn nên tập trung vị trí môi và lưỡi cho đúng\n\nHơi mở miệng ra, trãi rộng và căng môi ra\n\nĐưa phần giửa lưỡi lên vòm miệng và đẩy về phía trước.\n\nĐầu lưỡi hạ xuống, ngay phía sau răng cửa hàm dưới.\n\nHãy nhớ âm /ei/ là một âm căng miệng, nên môi và lưỡi thật căng ra.\n\nHàm nên hơi hạ thấp.\n\nBây giờ, hãy phát âm: \n\n/eɪ/\n\n/eɪ/\n\n/eɪ/\n\nBây giờ hãy tập phát âm này trong vài từ.\n\nBạn sẽ thấy một từ trên màn hình và nghe cách phát âm của nó.\n\nGiống như thế này:\n\nBạn sẽ có một vài giây để phát âm từ đó nếu muốn\n\nChúng ta hãy bắt đầu!\n\nXong rồi!\n\nXin chúc mừng!\n\n/ei/ là một trong những âm nguyên âm chính trong tiếng Anh Mỹ và nó cũng là phát âm của ký tự đầu tiên trong bảng chữ cái tiếng Anh\n\nCho nên khi bạn nghe âm / ei/, bạn có thể giả định nó nên được đánh vần với 'a'.\n\nVà bạn đúng, nhưng chỉ 73% số lần thôi\n\nVì 27% số lần còn lại được chia cho sự kết hợp các ký tự sau:\n\nnhư là 'ai' trong từ "wait"\n\n'ay', như trong từ "day"\n\n'ei', như trong từ "eight"\n\nhoặc 'ea' như trong "break."\n\nChúng ta cũng thấy không có một khuôn mẩu nào hết : )\n\nCám ơn bạn đã xem!\n\nHy vọng nó có ích cho bạn!\n\nHãy đón xem kênh Sounds American của chúng tôi!	2023-06-29 09:53:25.733	2023-06-29 09:53:25.733
334	220	1	CHIẾN LƯỢC LÀM BÀI PART 2 TOEIC KHÔNG PHẢI AI CŨNG BIẾT!	1	https://www.youtube.com/watch?v=0vRm_cl2J3k&ab_channel=AnhNg%E1%BB%AFAthena	0	0		 Một số mẹo nhỏ bạn cần phải biết khi làm part 2 TOEIC\nMột là, bạn phải lắng nghe thật kĩ từ để hỏi trong bài nghe, khi nghe một câu hỏi bạn phải nắm bắt được từ để hỏi trong câu là gì? Điều này giúp bạn có thể đoán được câu trả lời tốt hơn trong trường hợp bạn không nghe được toàn bộ câu hỏi. Khi nghe bạn sẽ phải nhớ cả câu hỏi lẫn đáp án nên khi đã nắm bắt được ý của câu hỏi muốn nói về vấn đề gì thì khi các lựa chọn được đọc lên bạn dễ dàng loại bỏ đáp án sai và tập trung nghe các đáp án tiếp theo, không nên mải nhớ đáp án cũ mà quên nghe đáp án mới.\n\nHai là, ở các câu hỏi sau bạn cần tập trung cao độ hơn để nghe chính xác nội dung câu hỏi, vì có thể các câu trả lời sẽ không trực tiếp như ở phần đầu nữa. Vì vậy, khi nghe câu hỏi bạn phải nhớ ngay nội dung của nó là gì để loại bỏ những đáp án không phù hợp.\n\nBa là, chú ý lắng nghe thật kĩ phần thì của câu hỏi, có rất nhiều câu ở phần 2 chỉ cần chúng ta nghe được thì của câu hỏi thì việc lựa chọn đáp án sẽ trở nên dễ dàng hơn.\n\nEg: How much will this room cost?\n\nA. It took less than a week\n\nB. I hired John to do\n\nC. About $5000\n\nCâu này hỏi là phòng này bao nhiêu tiền => đáp án C khoảng 5000$ là đúng.\n\nCòn đáp án A, B thì không vừa không đúng về nghĩa vừa không đúng thì trong câu. Câu hỏi là thì tương lai vậy nên câu trả lời nằm quá khứ là chắc chắn không đúng.\n\n \n\nBí kíp tránh bẫy và cách làm bài giúp bạn “ôm” trọn điểm part 2\nMột số bẫy thường gặp trong part 2\nTừ đồng âm\nKhi nghe các bạn sẽ thấy các từ nghe được trong câu hỏi và đáp án la lá giống nhau, nhiều bạn lơ là,không để ý dễ dẫn đến việc chọn sai đáp án. Để không bị “mắc bẫy” các bạn hãy  trau dồi cho nguồn vốn từ của mình các cặp từ đồng âm hay gặp trong bài thi Toeic để “cảnh giác” với chúng.\n\nEg:\n\nA: I love your new dress!\n\nB: I knew the answer as soon as she asked the question.\n\nTừ đồng âm khác nghĩa\nTừ có phát âm giống nhau nhưng lại khác về mặt nghĩa cũng là một “bẫy” khá khó khăn với chúng ta, bạn cần phải đặc biệt lưu tâm về loại từ này.\n\nEg:\n\nA: Go to sea in the summer enjoy\n\nB: What do you see in that house?\n\nNgoài ra còn có những từ có cùng chính tả và phát âm như nhau nhưng lại khác về mặt nghĩa lại càng khiến chúng ta “đau đầu” hơn rất nhiều. trường hợp này cũng gặp khá nhiều trong bài thi Toeic nên các bạn lưu ý nhé!\n\nEg:\n\nA: You like this book\n\nB:  I want to book tickets to Da Nang next week\n\n \n\nMẹo làm bài part 2 TOEIC với từng loại câu hỏi\nĐối với bài nghe, bắt buộc các bạn phải nghe được câu hỏi thì mới trả lời được. Dù bạn có nghe được tất cả 3 câu hỏi mà không nghe được câu hỏi thì cũng vô ích.\n\nTiếp theo là, bạn cần tập trung nghe các keywords, nghe càng được nhiều từ trong câu càng tốt, nghe được càng nhiều thì càng có nhiều thông tin nên càng dễ trả lời.\n\nVà điều quan trọng là bạn cần xác định dạng câu hỏi: WH hay YES/NO, câu hỏi đuôi, câu hỏi lựa chọn, Statement (câu trần thuật - đây là dạng khó )\n\n1.Câu hỏi Wh:\n ♦ What: Cái gì?\n\n+ Câu trả lời là danh từ chỉ vật\n\n+ Các câu hỏi “what” thường rất khó nên các bạn cần nghe các keywords phía sau.\n\nEg. What’s the name of the medical clinic that you go to?\n\nA. To see Dr. Paulson\n\nB. It’s a great job\n\nC. Norrell Health Center\n\n=>Đáp án C\n\nChú ý: What for = Why, What day = when, What place = where, what way = how\n\n \n\n ♦ Câu hỏi who:\n\n Loại trừ các câu trả lời có Yes/ No\n\n Câu trả lời đúng phải là người: +tên riêng (Tom, mr John…),\n\n+tên nghề nghiệp, chức vụ ( manager, officer,…)\n\nEg: Who’s that man speaking to Mr. Douglas\n\n(Người đàn ông đang nói chuyện với ông Douglas là ai?)\n\nA.They haven’t been waiting too long\n\nB.Usually at least twice a week\n\nC. He’s a reporter for the local newpaper\n\n=>Đáp án C\n\nChú ý:  Thì của câu trả lời phải khớp với thì của câu hỏi. Đây là một mẹo cực kì quan trọng và hữu ích.\n\nEg: Who will meet me at the airport?\n\nA. Chang, our sales manager\n\nB. Yes, between eleven and twelve\n\nC. There’s a good one nearby\n\n=>Đáp án A\n\n \n\n ♦ Câu hỏi when \n\n=> hỏi về mốc thời gian thì câu trả lời thường có:Giới từ chỉ thời gian:\n\n In about 2 years, ( approximately/roughly = about)\n\n At ( thời gian cụ thể ), at the end of\n\n On + ngày · By ( trước).\n\nEg. Trang has to submit her homework by Tuesday.\n\nMệnh đề thời gian ( có liên từ thời gian: when, not until, as soon as, before, after…)\n\nEg. When are you planning to go on vacation?\n\nA. It’s near a lake\n\nB. In December\n\nC. For two weeks\n\n=> Đáp án B\n\nChú ý: Thời gian của câu trả lời phải khớp với thì của câu hỏi ( hiện tại, quá khứ, tương lai )\n\n \n\n ♦ Câu hỏi Where \n\n=> ( hỏi về nơi chốn nên câu trả lời thường có Giới từ chỉ nơi chốn)\n\n In + nơi chốn ( in living room, in storage room,…)\n\n At + địa điểm cụ thể ( at school, at the corner of the room…)\n\n Next to, near, close to, opposite ( đối diện), across ( bên kia đường ), in front of, behind,.. · From/ To + địa điểm ( từ đâu/ đến đâu )\n\nEg: Where is conference room 11B?\n\nA. Thanks, I’ll be there soon\n\nB. It’s at the end of the hall\n\nC. That bookshelf has one\n\n=> Đáp án B\n\n \n\n ♦ Câu hỏi why\n\n Thường trả lời bằng “because/ because of/ due to/ owning to/ as/ since/ thank to” ♦\n\n Tuy nhiên nhiều câu không có “because”, nghĩa vẫn ổn thì vẫn được chọn\n\nEg: Why are you travelling to Denver?\n\nA. Only for a few days\n\nB.To spend time with my relatives\n\nC. I’m planning to drive there\n\n=> Đáp án B\n\nLưu ý: Why don’t +….: câu hỏi gợi ý = how about/what about + V-ing = Let’s + V(nguyên mẫu)\n\n=>>>> Câu trả lời: · Đồng ý: That’s good idea, Sure!, I’d love to, It sound good · Từ chối: Sorry, …\n\n \n\n ♦ Câu hỏi What for \n\nHỏi mục đích, để làm gì\n\nEg: What did you do that for?\n\n=>>>>Câu trả lời thường có các từ chỉ mục đích: To + V, in order to + V, so that + mệnh đề…\n\n \n\n♦ Câu hỏi how\n\n Hỏi về phương tiện, cách thức => câu trả lời: By + phương tiện, on foot/ on walk (đi bộ)\n\n How do you go to school? => By bus\n\n How many, how much: Hỏi về số lượng => câu trả lời thường có số lượng\n\n How much: hỏi về giá => câu trả lời có giá tiền\n\n How often: hỏi về mức đồ tần suất. Eg: How often do you meet your girlfriend?\n\n How long: Hỏi bao lâu => câu trả lời có khoảng thời gian.\n\n=>>> Cần phân biệt “how long” – khoảng thời gian với “when” – mốc thời gian\n\n \n\n ♦ Câu hỏi Yes/No:\n\nCăn bản: Đảo trợ động từ lên trước chủ ngữ\n\nEg: Did Lena deposit the checks at the bank? \n\n=> đồng tình: Yes, I did; không đồng tình: No, I didn’t\n\nCâu hỏi phủ định: Đảo trợ động từ phủ định lên trước chủ ngữ\n\nEg: Didn’t Lena deposit the checks at the bank? ( có ý nghi ngờ )\n\n=> đồng tình: No, I didn’t; Không đồng tình: Yes, I did\n\nTuy nhiên các câu trả lời nhiều khi không có did, didn’t mà nó đưa ra thêm thông tin cho mình nên cần phải nghe cẩn thận.\n\nEg: Did you go buy the book yesterday? => No. I was busy\n\n \n\n ♦ Câu tường thuật\n\nĐưa ra tình huống đòi hỏi người nghe phải có câu trả lời hợp lý\n\nĐưa ra câu nhận định => đưa ra ý kiến đồng tình hoặc phản đối\n\nCâu trả lời càng lặp thì câu trả lời đó càng bẫy và dễ sai\n\nCâu statement đưa ra gợi ý/ giải pháp\n\n \n\nNhững câu trả lời luôn ĐÚNG hay gặp trong PART 2 TOIEC\n\n ♦ I don’t know\n\n ♦ I have no idea\n\n ♦ I don’t have any clue\n\n ♦ I haven’t heard of it\n\n ♦ It hasn’t been decided yet\n\n ♦ We are not quite sure yet\n\n ♦ They didn’t say anything about it\n\n ♦ Beats me\n\n ♦ How would I know?\n\n \n\n2.Câu hỏi dạng lựa chọn\nWhich do you prefer A or B hay Do (es) chủ ngữ + V1 or V2\n\nTừ khóa cần quan tâm: “ A or B”\n\nTrong trường hợp này loại ngay câu trả lời chứa Yes hoặc No\n\nQ: Would you rather discuss this before he arrives, or during lunch?\n\nA: Let’s talk about it now.\n\n \n\n3.Câu hỏi khẳng định có chức năng hỏi\nYou+ động từ?\n\nHoặc:  I wonder if/từ nghi vấn+ chủ ngữ+ động từ\n\nTừ  khóa các quan tâm: Động từ hoặc nghi vấn\n\nQ: I wonder why Susan parked so far away\n\nA: She said the parking lot was completely filled\n\n \n\n4.Câu hỏi phủ định\n ♦ Aren’t you/ Isn’t he/won’t you\n\n ♦ Do you mind/ would you mind?\n\nTừ khóa: Động từ\nĐây là dạng câu hỏi dễ nhất trong part 2. Bạn chỉ cần chọn đáp án có chứa Yes hay No trong câu trả lời.\nNgoài việc áp dụng các chiến thuật luyện nghe trên, để đạt được điểm cao trong phần thi này các bạn cũng đừng quên trau dồi từ vựng part 2 toeic nhé.	2023-06-29 10:05:38.458	2023-06-29 10:05:38.458
306	203	2	Chữa đề Cam 10 - Test 2 - Part 3	1	https://www.youtube.com/watch?v=VvMn9TCrkVQ&ab_channel=STUDY4	0	0		 	2023-06-29 09:04:59.756	2023-06-29 09:04:59.756
335	220	2	Chiến thuật làm bài thi TOEIC Listening chinh phục điểm tuyệt đối	2		0	0	<p>Khác với hầu hết các kì thi giám định <a href="https://zim.vn/trinh-do-tieng-anh"><strong>trình độ tiếng Anh</strong></a> hiện hành, <a href="https://zim.vn/toeic-la-gi"><strong>TOEIC</strong></a> không đánh giá khả năng sử dụng ngôn ngữ trong hoàn cảnh học thuật - mà kiểm tra sự thông thạo dưới bối cảnh chuyên nghiệp, sát với đời sống thường ngày của người đi làm. Bài viết này sẽ giới thiệu về phần thi TOEIC Listening, cũng như cung cấp cho độc giả một số chiến thuật làm bài để góp phần giúp thí sinh chinh phục được tấm bằng giá trị này.</p><figure class="table"><table><tbody><tr><th colspan="1" rowspan="1"><strong>Key takeaways</strong></th></tr><tr><th colspan="1" rowspan="1"><p>Bài TOEIC Listening có 100 câu hỏi được chia ra thành 4 phần và kéo dài trong vòng 45 phút:</p><p>Phần 1: nội dung nghe gồm 4 phát biểu về một bức ảnh, yêu cầu chọn phát biểu nào mô tả đúng nhất về bức ảnh đã cho</p><p>Phần 2: nội dung nghe gồm 1 câu hỏi và 3 câu trả lời, yêu cầu chọn câu trả lời hợp lý nhất</p><p>Phần 3:&nbsp;nội dung nghe gồm một cuộc hội thoại, yêu cầu hoàn thành một số câu hỏi liên quan</p><p>Phần 4: nội dung nghe gồm một bài phát biểu ngắn, ví dụ như một thông báo hoặc một bài tường thuật, yêu cầu hoàn thành một số câu hỏi liên quan</p><p>Chiến thuật làm bài cho từng phần thi TOEIC Listening.</p></th></tr></tbody></table></figure><figure class="image"><img src="https://media.zim.vn/6361f229d830330029274f8a/lo-trinh-hoc-toeic-100.webp" alt="quang-cao-zim"></figure><p><a href="https://graph-api.zim.vn/ad-click?id=6361f2b8384ed4002797fb01">ZIM.VNLuyện thi TOEIC cam kết đầu ra bằng văn bản tại ZIM AcademyKhóa học luyện thi TOEIC 4 kỹ năng với phương pháp học tập cá nhân hóa chuyên sâu, phương pháp làm bài cập nhập liên tục, cam kết đầu ra bằng văn bản</a></p><h2>Cấu trúc bài thi TOEIC Listening</h2><p>TOEIC Listening là bài thi trắc nghiệm nhằm đánh giá một trong hai kĩ năng tiếp nhận (trong tiếng Anh là receptive skill) đó là kĩ năng Nghe, có ngân hàng đề thi được thiết kế sao cho tránh sự hàn lâm và gần gũi hơn với đời sống văn phòng chuyên nghiệp. Thí sinh sẽ phải trả lời 100 câu hỏi được chia ra thành 4 phần trong vòng 45 phút, sử dụng dữ liệu từ tờ đề thi và những đoạn thu âm phát duy nhất một lần.</p><p>Phần 1 đòi hỏi thí sinh nghe 6 câu hỏi gồm 4 phát biểu không được in trên tờ đề thi về một bức ảnh, trong khi phần 2 bắt buộc thí sinh lắng nghe 25 câu có nội dung là 1 câu hỏi cùng 3 câu trả lời. Về phần 3 với 39 câu hỏi, người làm bài sẽ nghe một cuộc hội thoại, sau đó hoàn thành một số câu hỏi về những gì mình vừa nghe. Còn với phần 4, đoạn băng sẽ phát một bài phát biểu ngắn, ví dụ như một thông báo hoặc một bài tường thuật, làm dữ liệu để trả lời 30 câu hỏi cuối cùng trong phần thi TOEIC Listening. Sau khi nghe, thí sinh cần chuyển đáp án của mình vào tờ ghi đáp án bằng cách tô đậm chữ A, B, C, hoặc D trên mẫu chép đáp án.</p><blockquote><p><i><strong>Tham khảo thêm: </strong></i><a href="https://zim.vn/lam-the-nao-de-nghe-hieu-qua-hon-trong-bai-thi-toeic-listening"><i><strong>Làm thế nào để nghe hiệu quả hơn trong bài thi TOEIC Listening</strong></i></a><i><strong>.</strong></i></p></blockquote><h2>Chiến thuật làm bài thi TOEIC Listening</h2><h3>Chiến thuật làm TOEIC Listening Part 1</h3><figure class="image"><img src="https://media.zim.vn/640e9577bf85a7cdf5e6cff3/part-1-toeic-listening.jpg" alt="Chiến thuật làm TOEIC Listening Part 1"></figure><p>Với mỗi câu hỏi trong số 6 câu xuất hiện trong phần 1, thí sinh sẽ được nghe bốn phát biểu không được in trên tờ đề thi. Thông tin duy nhất thí sinh có thể thấy trên giấy ghi đề bài là những bức ảnh, và thí sinh sẽ phải nghe và lựa chọn phát biểu nào mô tả đúng về bức ảnh nhất.</p><p>Những chiến thuật sau đây có thể sẽ giúp thí sinh hoàn thành bài thi TOEIC Listening Part 1 tốt hơn:</p><p><strong>Xem kĩ và phân tích bức ảnh được cho</strong>: Khi được cho phép xem đề bài, thí sinh nên tận dụng thời gian để quan sát và nhận diện những đặc điểm nổi bật trong các bức ảnh.&nbsp;</p><p><strong>Đưa ra những phán đoán về câu trả lời đúng</strong>: Trong khi quan sát các bức ảnh trong tờ đề bài, thí sinh nên suy nghĩ và tự đặt những câu mô tả về nội dung của chúng. Điều này sẽ giúp thí sinh nhận diện ngay câu trả lời đúng trong trường hợp phán đoán ban đầu của mình là chính xác.</p><p><strong>Chú ý đến chi tiết</strong>: Thông thường, những đáp án sai sẽ có một vài chi tiết nhỏ không hợp lý, khiến nghĩa của câu đó trở nên không chính xác so với nội dung nghe hoặc lệch khỏi trọng tâm câu hỏi. Thí sinh có nhiệm vụ lắng nghe kĩ để lọc ra những chi tiết bất thường.</p><blockquote><p><i><strong>Đọc thêm: </strong></i><a href="https://zim.vn/toeic-listening-part-1-va-phuong-phap-lam-bai-hieu-qua"><i><strong>Phương pháp làm bài TOEIC Listening Part 1</strong></i></a></p></blockquote><h3>Chiến thuật làm TOEIC Listening Part 2</h3><figure class="image"><img src="https://media.zim.vn/640e9592877bcb5ca295226c/part-2-toeic-listening.jpg" alt="Chiến thuật làm TOEIC Listening Part 2"></figure><p>25 câu ở phần 2 bắt buộc thí sinh nghe ba câu trả lời cho một câu hỏi nào đó - tất cả đều chỉ được phát trong cuốn băng ghi âm, không xuất hiện trên đề thi. Thí sinh cần ghi nhớ tất cả dữ liệu trong một lần nghe duy nhất cho mỗi câu, và lựa chọn câu trả lời hợp lý nhất.</p><p>Những chiến thuật sau đây có thể sẽ giúp thí sinh hoàn thành bài thi TOEIC Listening Part 2 tốt hơn:</p><p><strong>Xác định dạng câu hỏi</strong>: Thí sinh cần nhận diện câu hỏi cần trả lời. Những câu hỏi xuất hiện có thể là câu hỏi với từ để hỏi (Wh- words), câu hỏi Yes-No, câu hỏi đuôi, vv…. Khi đã xác định được loại câu hỏi trong cuốn băng, thí sinh có thể dễ dàng loại bỏ những câu trả lời có cấu trúc không khớp với câu hỏi, nếu có.</p><p><strong>Nghe kĩ toàn bộ ba câu trả lời trước khi lựa chọn</strong>: Kể cả khi câu trả lời đầu tiên có vẻ như là đáp án đúng, thí sinh cũng nên nghe tiếp để xem xét toàn bộ các lựa chọn của mình. Đôi khi, những câu trả lời tiếp theo lại mới là đáp án chính xác.</p><p>&nbsp;</p><blockquote><p><i><strong>Tham khảo thêm: </strong></i><a href="https://zim.vn/cac-dang-bai-toeic-listening-part-2-va-phuong-phap-xu-ly"><i><strong>Các dạng bài TOEIC Listening Part 2 và phương pháp xử lý</strong></i></a></p></blockquote><h3>Chiến thuật làm TOEIC Listening Part 3</h3><figure class="image"><img src="https://media.zim.vn/640e95a8877bcb5ca2952359/part-3-toeic-listening.jpg" alt="Chiến thuật làm TOEIC Listening Part 3"></figure><p>Phần 3 có dữ liệu nghe dài hơn cũng như yêu cầu khả năng nghe và tập trung cao hơn với 13 cuộc hội thoại và 39 câu hỏi, và thí sinh được cung cấp những câu hỏi và các đáp án A, B, C, D trên giấy. Ở phần này, nhiệm vụ của người làm bài là trả lời các câu hỏi về nội dung các cuộc nói chuyện đã được nghe.</p><p>Những chiến thuật sau đây có thể sẽ giúp thí sinh hoàn thành bài thi <a href="https://zim.vn/cac-dang-bai-trong-toeic-listening-part-3-va-cach-tiep-can-p-1"><strong>TOEIC Listening Part 3</strong></a> tốt hơn:</p><p><strong>Xác định</strong> từ khóa <strong>ở đề bài</strong>: Do các câu hỏi đều được in trong tờ đề thi nên thí sinh sẽ có cơ hội đọc hiểu và phân tích đề. Trong quá trình đó, nên nhận diện các từ khóa để hiểu nội dung và đưa ra một số phán đoán ban đầu về nội dung sắp được nghe.</p><p><strong>Cẩn thận với</strong> từ đồng nghĩa: Thông thường, nội dung trong đoạn băng ghi âm sẽ không chứa những từ đã xuất hiện trong đề bài được in trên giấy, mà sẽ sử dụng các <a href="https://zim.vn/tu-dong-nghia-synonyms-la-gi"><strong>từ đồng nghĩa</strong></a> hoặc paraphrase (viết lại sao cho ý nghĩa vẫn được giữ nguyên) những dữ liệu có trong câu trả lời đúng. Vì vậy, thí sinh nên suy nghĩ về những từ đồng nghĩa với các từ khóa mình tìm được trong đề, đồng thời cảnh giác với chúng trong quá trình nghe.</p><h3>Chiến thuật làm TOEIC Listening Part 4</h3><figure class="image"><img src="https://media.zim.vn/640e95c1bf85a7cdf5e6d369/part-4-toeic-listening.jpg" alt="Chiến thuật làm TOEIC Listening Part 4"></figure><p>Phần 4 gồm 10 bài phát biểu ngắn và 30 câu hỏi. Thí sinh sẽ được nghe cả phần bài nói và các câu hỏi tương ứng với mỗi bài (mỗi bài phát biểu sẽ có một số câu hỏi nhất định), nhưng chỉ phần câu hỏi và các lựa chọn A, B, C, D mới được in trong giấy ghi đề bài. Vì vậy, ở phần này người làm bài nên tập trung để thu thập đủ dữ liệu từ bài nghe và hoàn thành các câu hỏi đã cho.</p><p>Những chiến thuật sau đây có thể sẽ giúp thí sinh hoàn thành bài thi <a href="https://zim.vn/cach-tiep-can-cac-dang-bai-trong-toeic-listening-part-4"><strong>TOEIC Listening Part 4</strong></a> tốt hơn:</p><p><strong>Xác định từ khóa ở đề bài: </strong>Tương tự phần bài 3, phần 4 cũng cho phép người thi có thể đọc hiểu và phân tích đề trước khi nghe, nên thí sinh cần tận dụng điều đó và nhận diện các từ khóa ở đề bài để thuận lợi hơn cho quá trình nghe và xác định đáp án đúng.</p><p>&nbsp;</p><p><strong>Đọc kĩ và cố gắng ghi nhớ các câu hỏi dành cho mỗi đoạn thu âm</strong>: Do mỗi đoạn thu âm sẽ ứng với nhiều câu hỏi, nên thí sinh cần nắm được các câu hỏi và xác định trước nội dung mình cần lọc ra từ đoạn ghi âm. Vì vậy, cần đọc và hiểu kĩ các câu hỏi, tránh trường hợp bị lỡ mất thông tin trong bài nghe.</p><p>&nbsp;</p><p><strong>Nắm bắt mạch nội dung của bài nghe</strong>: Khi nghe một bài văn nói ngắn nhưng chứa khá nhiều thông tin như vậy, thí sinh cần bắt được mạch chính của bài và tập trung cao độ khi dữ liệu cần thiết sắp xuất hiện. Trước khi nghe, có thể phần nào đoán được nội dung và cấu trúc của bài nói thông qua các câu hỏi.&nbsp;</p><p>&nbsp;</p><h2>Tổng kết</h2><p>Để đạt được số điểm cao trong TOEIC Listening không dễ, nhưng nếu các sĩ tử chuẩn bị kĩ càng và ôn luyện đầy đủ, cơ hội đó sẽ cao hơn rất nhiều. Với phần thi này, vì hầu hết dữ liệu trong bài đều chỉ xuất hiện trong đoạn băng ghi âm, nên thí sinh cần rèn luyện sự tập trung và trí nhớ của mình để đáp ứng yêu cầu bài thi. Thí sinh có thể chọn lọc ra những chiến thuật mình thích từ bài viết này để áp dụng vào bài làm của mình.</p>	 	2023-06-29 10:06:14.575	2023-06-29 10:06:14.575
307	204	1	4 chiến lược làm đề thi IELTS Reading bạn nên biết	2		0	0	<p>Có thể nói IELTS Reading là phần thi tương đối dễ hơn so với các phần thi còn lại. Kỹ năng này sẽ kéo điểm của những kỹ năng còn lại, giúp điểm overall của bạn đạt mức mong muốn. Do đó, bài viết dưới đây PREP xin tổng hợp một số <a href="https://prep.vn/blog/chien-luoc-lam-de-thi-ielts-reading/"><strong>chiến lược làm đề thi IELTS Reading</strong></a> quan trọng bạn nên nắm chắc. Mong rằng bài viết hữu ích này giúp bạn vượt qua phần thi IELTS Reading một cách dễ dàng nhất.</p><figure class="image"><img src="https://prep.vn/blog/wp-content/uploads/2021/12/chien-luoc-lam-de-ielts-reading.jpg" alt="Chiến lược làm đề thi IELTS Reading bạn nên biết" srcset="https://prep.vn/blog/wp-content/uploads/2021/12/chien-luoc-lam-de-ielts-reading.jpg 900w, https://prep.vn/blog/wp-content/uploads/2021/12/chien-luoc-lam-de-ielts-reading-500x500.jpg 500w, https://prep.vn/blog/wp-content/uploads/2021/12/chien-luoc-lam-de-ielts-reading-150x150.jpg 150w, https://prep.vn/blog/wp-content/uploads/2021/12/chien-luoc-lam-de-ielts-reading-768x768.jpg 768w" sizes="100vw" width="900"></figure><p><i>Chiến lược làm đề thi IELTS Reading bạn nên biết</i></p><h3>&nbsp;</h3><ol><li>&nbsp;</li><li>&nbsp;</li><li>&nbsp;</li><li>&nbsp;<ol><li>&nbsp;</li><li>&nbsp;</li><li>&nbsp;</li></ol></li></ol><h2><strong>I. Chú ý đến thời gian làm bài và củng cố vốn từ vựng</strong></h2><p>IELTS Học thuật (Academic), IELTS Tổng quát (General) có thời gian làm bài là 60 phút cho phần thi Reading. Với kinh nghiệm của nhiều thí sinh IELTS, đây là phần khó hoàn thành trọn vẹn nhất trong thời gian quy định. Đề thi gồm 40 câu hỏi sau trong 3 đoạn văn dài. Vậy mà trong 1 tiếng đồng hồ bạn phải hoàn thiện nhanh gọn. Điều này ngay cả những người nói tiếng Anh bản địa cũng khó mà hoàn thành phần thi này. Nếu như không có trong tay một chiến lược làm đề thi IELTS Reading khôn ngoan nhất.</p><p>Nội dung của IELTS Học thuật được trích dẫn từ bất cứ nguồn nào và đề cập về bất cứ điều gì. Có thể là lịch sử, khoa học hay các vấn đề nhiều người quan tâm. Biết rằng, bạn không phải là chuyên gia trong lĩnh vực nào hết. Do đó chiến lược làm đề thi IELTS Reading chính ở đây là lựa chọn ra thông tin hữu ích cho câu trả lời.</p><p>Nếu bạn đang nắm giữ một khối từ vựng phong phú thì đây chính là một lợi thế. Bởi các từ vựng trong đề thi IELTS Reading bao gồm nhiều từ ngữ chuyên ngành. Khi thông thạo từ vựng, bạn sẽ hiểu đề thi đọc dễ dàng. Như vậy bạn cũng bớt đi được một phần trong quá trình thi Reading IELTS.</p><p>Cân đối thời gian thật hợp lý để hoàn thiện cả 3 phần thi là một trong những chiến lược làm đề thi IELTS Reading. Nhớ rằng bạn chỉ có 20 phút dành cho mỗi đoạn mà thôi. Vậy nên, <a href="https://prep.vn/ielts"><strong>ôn luyện thi IELTS</strong></a> Reading tại nhà hiệu quả để giúp bạn bớt lúng túng, làm bài thật trơn tru trong phòng thi Reading thực chiến nhé!</p><p><strong>Tham khảo thêm:</strong></p><blockquote><p><a href="https://prep.vn/blog/luyen-de-thi-ielts-reading-mien-phi/"><strong>Tìm hiểu đề thi IELTS Reading 2022 mới nhất và phương pháp ôn luyện</strong></a></p></blockquote><h2><strong>II. Các loại câu hỏi hay gặp trong đề thi IELTS Reading</strong></h2><p>Trong đề thi IELTS Reading, mỗi đoạn sẽ có 10-15 câu hỏi. Thường sẽ có ít nhất 2 loại câu hỏi trong mỗi phần. Mỗi câu hỏi ứng với một điểm của phần thi. Nếu đã đang luyện đề thi Reading, chắc hẳn bạn sẽ quen với <a href="https://prep.vn/blog/dang-cau-hoi-trong-bai-thi-reading-ielts/"><strong>11 loại câu hỏi trong bài thi Reading IELTS</strong></a> sau:</p><ul><li>&nbsp;<ul><li><a href="https://prep.vn/blog/dang-bai-multiple-choice-trong-ielts-reading/"><strong>Multiple choice questions</strong></a> hay còn gọi là câu hỏi có nhiều lựa chọn.</li><li><a href="https://prep.vn/blog/xu-ly-dang-true-false-not-given-trong-ielts-reading/"><strong>Information identification questions</strong></a> hay còn gọi là câu hỏi xác định thông tin.</li><li><a href="https://prep.vn/blog/chinh-phuc-matching-information-trong-ielts-reading/"><strong>Information matching</strong></a> hay còn gọi là nối thông tin</li><li><a href="https://prep.vn/blog/xu-ly-dang-matching-headings-trong-ielts-reading/"><strong>Head Matching</strong></a> hay còn gọi là chọn tiêu đề</li><li><a href="https://prep.vn/blog/chinh-phuc-sentence-completion-trong-ielts-reading/"><strong>Sentence completion</strong></a> hay còn gọi là hoàn thành câu</li><li>Summary completion hay còn gọi là hoàn thành đoạn tóm tắt</li><li>Features matching hay còn gọi là nối đặc điểm</li><li>Matching sentence endings hay còn gọi là nối câu kết thúc</li><li><a href="https://prep.vn/blog/xu-ly-dang-short-answer-questions-trong-ielts-reading/"><strong>Short answer questions</strong></a> hay còn gọi là câu trả lời ngắn</li><li>Notes/table/diagram completion hay còn gọi là hoàn thành các ghi chú/ biểu đồ/ bảng tóm tắt)</li><li>Câu hỏi dạng <a href="https://prep.vn/blog/xu-ly-dang-true-false-not-given-trong-ielts-reading/"><strong>True/ False/ Not Given hoặc Yes/ No/ Not Given</strong></a></li></ul></li></ul><p>Chiến lược làm đề thi IELTS Reading chính là hãy tập làm quen với từng loại câu hỏi hàng ngày. Điều này giúp bạn tìm ra phương pháp làm bài hiệu quả nhất. Khi đó, thí sinh dễ phân loại được những dạng câu hỏi “ngốn” nhiều thời gian suy nghĩ. Từ đó xây dựng kế hoạch luyện tập hiệu quả.&nbsp;</p><h2><strong>III. Chiến lược làm đề thi IELTS Reading tại nhà hiệu quả</strong></h2><p>Chiến lược làm đề thi IELTS Reading chính là luyện tập khả năng đọc hiểu các đoạn văn tiếng Anh. Hàng ngày dành ra tối đa thời gian làm các bài kiểm tra thực hành. Điều này giúp thí sinh làm quen với loại câu hỏi trong đề thi IELTS Reading. Bên cạnh đó, hãy cải thiện cách đọc đề thi và nắm bắt ý chính trong đề. PREP.VN đã tổng hợp <a href="https://prep.vn/blog/de-thi-ielts-reading/"><strong>10+ đề thi IELTS Reading</strong></a> giúp bạn học luyện thi hiệu quả, tham khảo chi tiết bạn nhé!</p><p>Bạn nên tăng tốc độ<a href="https://prep.vn/blog/ky-nang-skimming-va-scanning-ielts-reading/#2-scanning-la-gi"><strong> Scanning</strong></a> hay còn gọi là được lướt. Suy nghĩ để hiểu nhanh ý chính của một bài viết bằng tiếng Anh. Điều này tạo ra lợi thế cho bạn khi làm đề thi. Cải thiện kỹ năng IELTS Reading giúp thí sinh tự tin khi đối mặt với đề thi rất dài. Đồng nghĩa là bạn phải dành thời gian để đọc thật nhiều. Hãy chăm đọc blog, tạp chí học thuật bằng tiếng Anh. Hay chọn một tờ báo tiếng Anh để cải thiện kỹ năng đọc hiểu.</p><p>Khi bạn càng chăm chỉ đọc tiếng Anh, Bạn sẽ càng mở rộng vốn từ vựng, cách sử dụng từ ngữ và kiến thức về nhiều vấn đề trong cuộc sống. Điều này vô cùng quan trọng trong quá trình làm đề thi. PREP xin gợi ý cho bạn một tip hữu ích cho trong quá trình đọc. Nếu bạn tìm thấy một từ bạn không biết nghĩa.</p><p>Hãy ghi lại từ đó vào sổ tay từ vựng là một trong những chiến lược làm đề thi IELTS Reading. Ngoài ra bạn cần nhóm lại danh sách những từ bạn cần biết nghĩa, bên cạnh đó là xem lại định nghĩa của chúng. Điều này giúp bạn ghi nhớ rất tốt và lâu hơn. Bên cạnh đó, cuốn cẩm nang từ vựng giúp bạn biết cách sử dụng từ ngữ phù hợp với bối cảnh cụ thể.</p><h2><strong>IV. Chiến lược dành cho các thí sinh trong lúc làm đề thi IELTS Reading</strong></h2><h3><strong>1. Scanning – Đọc lướt</strong></h3><p>Kĩ năng đọc lướt – chiến lược làm đề thi IELTS Reading giúp thí sinh thoải mái về thời gian hơn. Trong quá trình <a href="https://prep.vn/blog/ky-nang-skimming-va-scanning-ielts-reading/#2-scanning-la-gi"><strong>scanning</strong></a>, hãy đọc và nắm bắt thông tin quan trọng một cách nhanh chóng và hiệu quả. Trong quá trình luyện tập đề thi IELTS Reading tại nhà. Hãy thử scan qua mỗi đoạn 3-4 phút trước khi tiến hành trả lời các câu hỏi.</p><p>Để nâng cao kỹ năng này, PREP khuyên bạn nên thực hành đọc lướt qua các bài báo ngắn, script của một bài hát. Thêm nữa, nên dùng điện thoại của bạn để hẹn giờ là một chiến lược làm đề thi IELTS Reading hiệu quả. Có thể bạn sẽ vô cùng ngạc nhiên khi nhìn thấy kết quả hữu ích của phương pháp này đó.&nbsp;</p><figure class="image"><img src="https://prep.vn/blog/wp-content/uploads/2021/08/ky-nang-skimming-va-scanning-hoc-ielts-cho-nguoi-moi-bat-dau-e1640328549619.jpg" alt="Skimming và Scanning - Học IELTS cho người mới bắt đầu" srcset="https://prep.vn/blog/wp-content/uploads/2021/08/ky-nang-skimming-va-scanning-hoc-ielts-cho-nguoi-moi-bat-dau-e1640328549619.jpg 1230w, https://prep.vn/blog/wp-content/uploads/2021/08/ky-nang-skimming-va-scanning-hoc-ielts-cho-nguoi-moi-bat-dau-e1640328549619-500x510.jpg 500w, https://prep.vn/blog/wp-content/uploads/2021/08/ky-nang-skimming-va-scanning-hoc-ielts-cho-nguoi-moi-bat-dau-e1640328549619-1004x1024.jpg 1004w, https://prep.vn/blog/wp-content/uploads/2021/08/ky-nang-skimming-va-scanning-hoc-ielts-cho-nguoi-moi-bat-dau-e1640328549619-768x783.jpg 768w" sizes="100vw" width="1230"></figure><p><i>Skimming và Scanning – Học IELTS cho người mới bắt đầu</i></p><h3><strong>2. Gạch chân từ hoặc các cụm từ quan trọng</strong></h3><p>Song song với đọc lược, chiến lược làm đề thi IELTS Reading đó là hãy gạch chân từ/ cụm từ quan trọng. Nếu bạn nhận ra sự kiện, số liệu quan trọng liên quan đến câu trả lời thì hãy nhanh tay gạch chân cụm đó. Phương pháp này giúp bạn tiết kiệm thời gian để hoàn thiện đề thi IELTS Reading hiệu quả.</p><h3><strong>3. Chú ý key chính</strong></h3><p>Chiến lược làm đề thi IELTS Reading cuối cùng là bạn nên đọc câu hỏi thật kỹ càng. Khi đó bạn sẽ nhận biết được từ key chính trong câu hỏi. Điều này giúp bạn tránh được những lỗi sai đáng tiếc. Bên cạnh đó, chú ý đến yêu cầu trong câu hỏi. Quan sát kĩ càng, giúp bạn hoàn thành đề thi nhanh chóng nhất. Và cũng áp dụng tương tự với cách kỹ năng còn lại. Thực hành vẫn là một phương pháp hiệu quả. Khi đó bạn sẽ hoàn thiện bài thi trọn vẹn mà tránh khỏi những lỗi cơ bản.</p><p>Tham khảo 4 gợi ý về chiến lược làm đề thi IELTS Reading cùng <a href="https://prep.vn/"><strong>PREP.VN</strong></a> nha. Trau dồi ngay những chiến lược làm đề thi IELTS Reading để chinh phục được band điểm IELTS Reading thật cao bạn nhé!</p>	 	2023-06-29 09:08:05.31	2023-06-29 09:08:05.31
336	220	3	Mẹo làm bài thi TOEIC 7 phần “rinh trọn” số điểm 990 TOEIC	2		0	0	<h2><strong>I. TỔNG QUÁT VỀ ĐỀ THI TOEIC 2 KỸ NĂNG&nbsp;</strong></h2><p>Đề thi TOEIC hiện nay gồm 7 phần thi chính đặc biệt chú trọng vào hai kỹ năng là đọc và nghe. Đề thi gồm có 200 câu hỏi trắc nghiệm tiếng Anh với tổng thời gian thi 120 phút: 100 câu Listening tương đương part 1, 2, 3, 4 ( thi trong 45 phút) và 100 câu reading tương đương part 5, 6, 7 (thi trong 75 phút).&nbsp;</p><ul><li>Phần 1: (Photographs)-Phần Mô tả tranh</li><li>Phần 2: (Question – Response)-Phần Hỏi đáp</li><li>Phần 3: (Short Conversations)- Phần Đoạn hội thoại ngắn</li><li>Phần 4: (Short Talks)-Phần Bài nói ngắn</li><li>Phần 5: (Incomplete Sentences)-Phần Hoàn thành câu</li><li>Phần 6: (Text Completion)-Phần Hoàn thành đoạn văn</li><li>Phần 7: (Reading Comprehension)-Phần Đọc hiểu</li></ul><p>Các bạn thấy đó, mỗi một phần trong đề thi TOEIC có dạng câu hỏi khác nhau. Chính vì vậy, ở từng phần bạn phải có chiến lược riêng thì sẽ hoàn thành các câu hỏi nhanh nhất và có đáp án đúng.</p><p>Chúng ta hãy cùng nhau tìm hiểu mẹo của từng phần thi ngay thôi!</p><h2><strong>II. MẸO LÀM BÀI THI TOEIC 7 PHẦN HIỆU QUẢ NHẤT&nbsp;</strong></h2><figure class="image"><img src="https://prep.vn/blog/wp-content/uploads/2022/03/thang_diem_toeic.webp" alt="Mẹo làm bài thi TOEIC 7 phần “rinh trọn” số điểm 990 TOEIC"></figure><p><i>Mẹo làm bài thi TOEIC 7 phần “rinh trọn” số điểm 990 TOEIC</i></p><h3><strong>1.Hướng dẫn Các mẹo làm bài thi TOEIC Listening (Nghe)</strong></h3><p>Thời gian dành cho các bạn thí sinh để làm bài thi nghe này là&nbsp; 45 phút để có thể vừa nghe và vừa hoàn thành 100 câu hỏi. Chính vì vậy, điều bạn cần làm là áp dụng những chiến thuật – mẹo làm bài thi TOEIC sau đây để có thể hoàn thành bài thi Listening một cách tốt nhất:</p><p><i>✓ Bước 1: Tập trung luyện nghe 100% tâm trí vào bài thi.</i></p><p><i>✓ Bước 2:&nbsp; Đọc trước các câu hỏi trước khi nghe audio.</i></p><p><i>✓ Bước 3: Khi bạn không nghe kịp được câu hỏi thì hãy bỏ qua, đừng lo lắng và hồi hộp ảnh hưởng câu hỏi tiếp theo.</i></p><p><i>✓ Bước 4: Lưu ý tới những từ đồng nghĩa, trái nghĩa trong tiếng Anh sẽ được sử dụng nhiều để đánh lừa thí sinh.</i></p><h4><strong>➤ Phần 1: Dạng bài Picture Description( Mô tả tranh )&nbsp;</strong></h4><p>Trong phần bài thi này, các bạn sẽ được xem một bức&nbsp; ảnh chụp và các bạn sẽ được yêu cầu lựa chọn trả lời mô tả đúng những gì đang diễn ra trong hình, mô tả liên quan đến vị trí của đồ vật, con người.</p><p>Ở phần đầu tiên, tuy độ khó đề bài chưa cao, đề bài sẽ đánh lừa thí sinh bằng cách đưa ra mô tả hành động đúng nhưng làm khó bằng cách làm sai đối tượng, ngoài ra có thể là&nbsp; tranh tĩnh, tranh động dùng động từ để mô tả, và đặc biệt là dễ gây nhầm lẫn bằng các từ đồng âm, từ gần nghĩa, từ đa nghĩa như đã phân tích ở trên đó.</p><h4><strong>➤ Phần 2: Bài tập Question &amp; Response(Hỏi đáp)</strong></h4><p>Ở phần 2 của câu hỏi và đáp án, đúng như tên&nbsp; bài tập nhiệm vụ của các bạn là tìm được câu trả lời cho câu hỏi: where (ở đâu), when (khi nào), what (cái gì), who (ai), why (tại sao),how( làm thế nào).</p><p>Bởi vậy các bạn cần tập trung nghe kĩ dạng câu hỏi của mình để có thể xác định được đáp án chính xác, trường hợp không nghe kĩ hết các câu trả lời thì các bạn luôn có thể dự đoán đáp án một cách tốt nhất.</p><figure class="table"><table><tbody><tr><td><figure class="image"><img src="https://s.w.org/images/core/emoji/14.0.0/svg/1f525.svg" alt="🔥"></figure><p><strong>&nbsp;HỌC ĂN HỌC NÓI HỌC TRỌN GÓI TOEIC 800+ TỪ MẤT GỐC Ở ĐÂY!</strong>&nbsp;</p><figure class="image"><img src="https://s.w.org/images/core/emoji/14.0.0/svg/1f525.svg" alt="🔥"></figure><p><strong>Để lại thông tin và nhận lộ trình tự học theo ngày (Prep đã chia sẵn thời khóa biểu cho bạn) từ mất gốc lên 800+ TOEIC gói gọn chỉ trong 5 tháng!</strong></p><p><strong>NHẬN TƯ VẤN LỘ TRÌNH</strong></p></td></tr></tbody></table></figure><h4><strong>➤ Phần 3: Nghe một đoạn Hội thoại ngắn (Short Conversations)</strong></h4><p>Bạn sẽ được nghe một đoạn đối thoại và sau đó bạn có thời gian để trả lời câu hỏi, phần này khó hơn 3 phần trước một chút, nhưng nếu bạn có kỹ năng nghe tốt bạn hoàn toàn vẫn có thể dễ dàng trả lời câu hỏi một cách tự tin.</p><p>Để có thể nghe thành công trong phần Hội thoại ngắn, bạn phải đọc nhanh&nbsp; câu hỏi của&nbsp; hội thoại này và chú ý&nbsp; nội dung từ đầu đến cuối và nên cố gắng không bỏ sót một từ nào.</p><p>Phần này đòi hỏi cả tư duy logic để phán đoán câu trả lời và hơn hết là sự tập trung cao độ vào phần làm bài của thí sinh.</p><h4><strong>➤ Phần 4: Bài nói chuyện ngắn (Short Talks)</strong></h4><p>Đây là phần thi TOEIC Listening cuối cùng&nbsp; và phần này có rất nhiều bẫy gây khó khăn cho thí sinh.</p><p>Trong một cuộc hội thoại sẽ nói về một lĩnh vực cụ thể, vì vậy cần biết chính xác lĩnh vực mà người nói đang nói đến&nbsp; để có thể hiểu cách sử dụng các câu hỏi liên quan, điển hình như các lĩnh vực sau: Announcement (thông báo), Recorded message (tin nhắn thu âm), Advertisement (quảng cáo), Broadcast (chương trình phát sóng), Talk (lời nói, hội thoại), Report (tường thuật, câu chuyện) …</p><h3><strong>2. Các mẹo để làm bài thi TOEIC Reading (Đọc)</strong></h3><p>Trong bài thi TOEIC Reading, bạn sẽ khoản thời gian là 75 phút để trả lời 100 câu hỏi, để vượt qua bài kiểm tra hiệu quả, bạn phải chú ý một số điều như sau:</p><p>✓ Nắm vững kiến ​​thức về từ vựng và ngữ pháp tiếng Anh :, danh từ, động từ, tính từ, liên từ … Đây là những chủ điểm ngữ pháp thường gặp nhất trong Đề thi TOEIC Reading</p><p>✓ Dành thời gian làm bài hợp lý: Phần 7 là khó nhất&nbsp; nên bạn cần&nbsp; hoàn thành nhanh chóng. Các bạn hãy sớm hoàn thành phần 5,6 để có thời gian làm phần 7 nhé!</p><p>✓ Lưu ý Từ đồng nghĩa và Từ trái nghĩa: Trong bài thi TOEIC, bài thi sẽ&nbsp; bẫy&nbsp; thí sinh rất nhiều về các từ đồng nghĩa và trái nghĩa.</p><p>✓ Luyện kỹ năng đọc lướt và đọc lướt(Skimming and Scanning): đây là 2 kỹ năng mà bạn sẽ áp dụng&nbsp; rất nhiều trong bài thi TOEIC khi đọc</p><h4><strong>➤ Phần 5: Hoàn thành các câu&nbsp; (Incomplete Sentences)</strong></h4><p>Đây là phần thi đầu tiên trong bài thi TOEIC Reading nhưng lại có vô số bẫy được đặt ra. Ở phần thì này luôn luôn yêu cầu bạn phải có kiến thức ngữ pháp vững chắc.</p><h4><strong>➤ Phần 6: Hoàn thành một&nbsp; đoạn văn (Text Completion)</strong></h4><p>Phần này bao gồm 16 câu hỏi trắc nghiệm, được chia thành 4 đoạn, mỗi đoạn sẽ có 4 câu hỏi. Dạng câu hỏi sẽ tương tự như phần&nbsp; 5 trong phần&nbsp; về từ vựng và ngữ pháp tiếng Anh.</p><p>Các loại đoạn văn bạn thường gặp: email, bản ghi nhớ, thông báo, hướng dẫn, bài báo, thông báo …</p><h4><strong>➤ Phần 7: Phần Đọc hiểu (Reading Comprehension)</strong></h4><p>Đây là&nbsp; phần thi khó nhất và chiếm nhiều thời gian&nbsp; nhất của các thí sinh,&nbsp; vì vậy muốn đạt điểm TOEIC 800-&gt;990 thì&nbsp; các bạn phải hoàn thành tốt part 7. Thời gian của các bạn dành&nbsp; cho part 7 đó là 30-&gt;45 phút.</p><p><br>&nbsp;</p>	  	2023-06-29 10:07:21.556	2023-06-29 10:07:21.556
308	204	2	10 chiến thuật chinh phục 8.0 IELTS Listening	2		0	0	<p><strong>Phần thi IELTS Listening là một trong những phần thi khá khó nhằn vì thí sinh sẽ chỉ được nghe đúng một một lần duy nhất và không có nhiều cơ hội để chữa câu trả lời. Chính vì thế, để có được một phần thi IELTS Listening tốt nhất và đạt điểm cao, các bạn cần phải nắm được những chiến thuật làm bài và các bước chuẩn bị cần thiết. Trong bài viết này, GLN đã tổng hợp đầy đủ những chiến thuật cho phần thi IELTS Listening hữu dụng nhất để cải thiện điểm số của mình.&nbsp;</strong></p><p><strong>Nắm rõ cấu trúc của bài thi IELTS Listening.&nbsp;</strong></p><p>Bài thi IELTS Listening có tất cả 4 đoạn ghi âm – độc thoại và đàm thoại bởi một số người bản xứ. Phần thi này bao gồm các câu hỏi đánh giá năng lực của thí sinh trong việc nắm bắt các ý chính và thông tin thực tế một cách chi tiết. Đánh giá khả năng nhận thức quan điểm và thái độ của người nói, khả năng hiểu được mục đích của vấn đề được nói đến và khả năng theo kịp sự trình bày các ý kiến khác nhau. IELTS Listening sử dụng nhiều tiếng và giọng nói của người bản xứ. Bạn sẽ được nghe từng phần chỉ với một lần duy nhất.</p><figure class="image"><img src="https://gln.edu.vn/wp-content/uploads/2019/12/10-chien-thuat-chinh-phuc-8-0-ielts-listening-01.png" alt=""></figure><p><strong>Cấu trúc của bài thi:</strong></p><ul><li>Phần 1: Một đoạn đàm thoại giữa hai người trong ngữ cảnh xã hội hàng ngày. Ví dụ: một mẫu đàm thoại tại một đại lý thuê nhà.</li><li>Phần 2: Một đoạn độc thoại trong ngữ cảnh xã hội hàng ngày. Ví dụ: bài diễn văn về các tiện ích địa phương.</li><li>Phần 3: Một mẫu đàm thoại tối đa bốn người trong ngữ cảnh giáo dục và đào tạo. Ví dụ: Một giáo viên tại trường đại học và một sinh viên đang thảo luận về bài tập.</li><li>Phần 4: Một đoạn độc thoại về chủ đề học tập, nội dung học tập. Ví dụ: Một bài giảng đại học.</li></ul><p><strong>Làm quen với các dạng câu hỏi trong IELTS Listening.</strong></p><p>Về cơ bản, IELTS Listening có tất cả 8 dạng câu hỏi thường gặp:</p><ul><li><i>Dạng 1</i> – Multiple Choice Question: Đây là dạng câu hỏi trắc nghiệm tương đối dễ nhận biết. Mỗi câu hỏi sẽ đi cùng với 3 đến 4 đáp án và bạn phải lựa chọn 1 đáp án đúng.</li><li><i>Dạng 2</i> – Form Completion: Dựa trên các thông tin được cung cấp trong bài nghe, các bạn cần phải hoàn thành các chi tiết trong biểu mẫu cho sẵn.</li><li><i>Dạng 3</i> – Sentence Completion – Summary Completion: Dạng bài này yêu cầu thí sinh điền vào chỗ trống của một đoán tóm tắt từ bài nghe.</li><li><i>Dạng 4</i> – Table Completion: Đề bài sẽ cung cấp một bảng có liên quan tới bài nghe cùng một số chỗ trống. Thí sinh sẽ phải hoàn tất bảng thông tin đó bằng cách điền vào chỗ trống những từ cần thiết.</li><li><i>Dạng 5</i> – Labeling a Map/Diagram: Trong dạng bài này bạn cần phải điền một từ hoặc 1 cụm từ phù hợp từ danh sách cho sẵn để hoàn thành bản maps.</li><li><i>Dạng 6</i> – Matching Information: Thí sinh được yêu cầu để phân loại thông tin có trong bài nghe. Bạn được cung cấp một số thông tin nhất định và phải phân loại thông tin đó sao cho thích hợp nhất.</li><li><i>Dạng 7</i> – Short Answer Question: Dạng này có đề bài là một câu hỏi liên quan tới bài nghe và nhiệm vụ của thí sinh là phải trả lời câu hỏi đó trong giới hạn số từ cho phép.</li><li><i>Dạng 8</i> – Pick from a list: Bạn sẽ được cho một câu hỏi và một danh sách có trên 5 đáp án. Nhiệm vụ của bạn là phải chọn ra từ 2 – 3 câu trả lời đúng trong dãy đáp án đó.</li></ul><figure class="image"><img src="https://gln.edu.vn/wp-content/uploads/2019/12/10-chien-thuat-chinh-phuc-8-0-ielts-listening-02.png" alt=""></figure><p><strong>Gạch chân cẩn thận các keywords có trong đề thi.&nbsp;</strong></p><p>Thời gian cho phép của IELTS Listening không có nhiều và bạn chỉ được nghe mỗi đoạn hội thoại 1 lần duy nhất, do đó bạn sẽ không có thời gian để đọc hết các câu hỏi có trong đề. Chính vì thế, gạch chân các keyword là một bước cực kỳ quan trọng và cần thiết, đặc biệt là với những dạng câu hỏi có chứa nhiều thông tin như multiple choice, table completion… Việc gạch chân các từ khóa chính không chỉ giúp bạn tập trung hơn vào câu hỏi mà còn giúp bạn tóm lược thông tin tốt hơn, dễ dàng xử lý thông tin và không bị phân tâm bởi những thông tin thừa.</p><p><strong>Cẩn thận với bẫy trong bài.</strong></p><p>“Cẩn thận” được xem như 2 chữ vàng trong bài IELTS Listening vì bẫy gần như xuất hiện thường xuyên và khắp các dạng bài của phần thi này. Ví dụ ở section 1, người nói có thể đưa ra 1 con số rồi lại phủ nhận và đưa ra 1 con số khác. Tương tự như trong dạng multiple choice thì bạn có thể nghe được cả 3 đáp án và 2 trong số đó thường là bẫy. Bí quyết cho những bẫy này đó là nghe hiểu và bắt được những cụm từ mang tính phủ định, self- correction như: actually, no, pardon me, sorry, oh wait,…</p><p><strong>Viết đúng chính tả từ vựng và sử dụng đúng ngữ pháp.&nbsp;</strong></p><p>Bạn cần chắc chắn và cẩn thận khi điền đáp án của câu hỏi về từ vựng và ngữ pháp. Có rất nhiều trường hợp khi làm xong bài vô cùng chắc chắn đã nghe được 80% các câu hỏi, tuy nhiên kết quả khi kiểm tra lại thì chỉ được tầm 50%. Thí sinh cần chú ý đừng để mất điểm một cách đáng tiếc như thế vì lỗi ngữ pháp hay chính tả như danh từ số nhiều không thêm “s”, “ed”, đuôi “ing” không gấp đôi hay gấp đôi không đúng chỗ. Ngoài ra, một số danh từ chỉ cặp sẽ luôn ở dạng số nhiều như pants, glasses,… hay các danh từ số nhiều bất quy tắc mà chúng ta cũng cần ghi nhớ như sheep, fish, mice,…</p><figure class="image"><img src="https://gln.edu.vn/wp-content/uploads/2019/12/10-chien-thuat-chinh-phuc-8-0-ielts-listening-03.png" alt=""></figure><p><strong>Không cần phải biết hết mọi từ.&nbsp;</strong></p><p>Với IELTS nói chung và IELTS Listening nói riêng, các bạn không nhất thiết phải biết hết tất cả mọi từ được nhắc đến trong bài thi, vì việc này sẽ khiến bạn mất tập trung và mất thời gian không cần thiết. Nếu như có từ nào đó quá khó mà bạn không nghe được hoặc không hiểu thì hãy cứ bỏ qua và tập trung vào nội dung chính của câu và đoạn văn. Thực tế là việc đánh giá khả năng phân tích và hiểu thông tin của bạn trong Listening không phải là ở việc chúng ta cần phải biết 100% các từ trong 1 bài để được điểm tuyết đối.</p><p><strong>Phân chia thời gian làm bài hợp lý.&nbsp;</strong></p><p>Đối với mỗi section trong bài IELTS Listening, thí sinh sẽ có 1 phút để kiểm tra lại các câu trả lời và chuẩn bị cho section tiếp theo. Tuy nhiên, các bạn không nên đọc lại các câu trả lời một cách quá kỹ vì cuối phần Listening bạn cũng sẽ có thêm 10 phút để kiểm tra và điền đáp án vào tờ answer sheet. Chính vì thế, hãy tận dụng 1 phút quý giá thật là hợp lý để đọc trước section tiếp theo, gạch chân các keywords cần thiết và tập trung thật cao độ.</p><p><strong>Cảnh giác với thứ tự các câu hỏi.&nbsp;</strong></p><p>Trong các dạng câu hỏi như Map, Table, Biểu đồ,.. thì thứ tự câu hỏi không phải lúc nào cũng được sắp xếp từ trên xuống dưới. Vì vậy, trước khi làm bài bạn cần xác định rõ xem các câu hỏi đang có thứ tự như thế nào trong bài để có thể quản lý thông tin bài một cách cẩn thận và không bị mất điểm đáng tiếc.</p><p><strong>Không bỏ sót lại chỗ trống trong bài.&nbsp;</strong></p><p>Nếu câu trả lời sai thì bạn không được điểm chứ không bị trừ điểm. Chính vì thế, nếu bạn còn 1,2 câu trả lời mà bị bí chưa làm được thì đừng để trống lại mà hãy vận dụng hết khả năng suy đoán của mình để điền vào những đáp án thích hợp nhất nhé.</p><p><strong>Bỏ qua khi không nghe được.</strong></p><p>Khi chúng ta không nghe được 1 câu hỏi trong bài thường sẽ trở nên rất cuống và mất tập trung. Tuy nhiên, vì bạn chỉ được phép nghe các đoạn hội thoại 1 lần nên việc nghe lại các câu đã qua là điều không thể, còn nếu bạn suy nghĩ nhiều về nó thì còn ảnh hưởng đến việc nghe các câu còn lại. Vì vậy, nếu đã bị lỡ rồi thì bạn hãy cứ bỏ qua, tập trung 100% cho các câu tiếp theo và có thể suy đoán lại đáp án vào 10 phút cuối nhé.</p><p>&nbsp;</p><p>IELTS Listening luôn là vấn đề nan giải và khiến các bạn chùn vước vì độ khó và phức tạp. Tuy nhiên, chỉ với 10 bí quyết mà GLN vừa cung cấp trên đây thôi, tin chắc nếu các bạn thực hiện và luyện tập thật nhiều thì điểm Listening của bạn sẽ được cải thiện một cách rõ rệt cho mà xem.</p><p><i>Nếu bạn muốn tìm hiểu về các khóa học luyện thi IELTS tại Trung tâm tiếng Anh GLN, hãy liên hệ Trung tâm tư vấn qua số điện thoại 094 652 1646/ 0948 666 358&nbsp; để được giải đáp cụ thể và miễn phí.</i></p>	 	2023-06-29 09:09:07.336	2023-06-29 09:09:07.336
309	204	3	Cấu trúc đề thi IELTS Listening và các mẹo giúp bạn luyện thi hiệu quả	2		0	0	<p>Để làm tốt phần thi IELTS Listening, ngoài việc ôn luyện những kiến thức cần thiết, các bạn cũng cần tìm hiểu về cấu trúc đề thi IELTS Listening để biết cách làm bài thi sao cho hiệu quả nhất. Dưới đây là những thông tin chi tiết về cấu trúc bài thi dành cho bạn.</p><h2>Những điều bạn nên biết về cấu trúc đề thi IELTS Listening?</h2><p>Thời lượng của bài thi IELTS Listening là 30 phút. Đối với bài kiểm tra trên giấy, bạn sẽ có thêm 10 phút để chuyển câu trả lời của mình sang phiếu trả lời. Nhưng khi chọn hình thức thi online trên máy tính, bạn sẽ có 2 phút để kiểm tra lại câu trả lời của mình.</p><p>Bạn sẽ phải trải qua bốn phần trong bài thi Listening với mức độ khó tăng dần. Mỗi phần có 10 câu hỏi, tổng cộng 40 câu với mỗi câu tương ứng 1 điểm. Giám khảo cho bạn thời gian để xem xét các câu hỏi trước khi bạn bắt đầu nghe đoạn ghi âm được phát và cuối cùng, bạn sẽ có thời gian để xem lại các câu trả lời mà bạn đã viết.&nbsp;</p><p>Cấu trúc đề thi IELTS Listening dành chung cho cả 2 loại hình IELTS Học thuật và IELTS Tổng quát.</p><p>Hãy thận trọng khi đọc yêu cầu làm bài về số lượng từ được phép có trong câu trả lời, vì một số yêu cầu chỉ định bạn sẽ chỉ điền một từ, hai từ hoặc 1 con số nào đó, v.v... Ngoài ra, bạn cũng cần chuẩn bị khả năng phân tích câu hỏi, vốn từ vựng phong phú, đặc biệt là những từ đồng nghĩa, vì các từ vựng sử dụng trong bài nghe sẽ không giống với câu hỏi mà đôi khi chúng được diễn giải bằng các từ đồng nghĩa.</p><p>Dưới đây là bảng mô tả chi tiết 04 phần có trong đề thi IELTS Listening:</p><figure class="table"><table><tbody><tr><td><strong>Phần 1</strong></td><td>Cuộc trò chuyện giữa 2 người xoay quanh các chủ đề trong cuộc sống hàng ngày. (ví dụ: một cuộc trò chuyện để đặt phòng trong khách sạn)</td></tr><tr><td><strong>Phần 2</strong></td><td>Một đoạn độc thoại đặc trưng về cuộc sống hàng ngày. (ví dụ: một cuộc nói chuyện về việc sử dụng thời gian một cách hiệu quả)</td></tr><tr><td><strong>Phần 3</strong></td><td>Cuộc hội thoại giữa 3 hoặc 4 người về chủ đề giáo dục hoặc đào tạo. (ví dụ: sinh viên thảo luận về bài tập)</td></tr><tr><td><strong>Phần 4</strong></td><td>Độc thoại liên quan đến học thuật.&nbsp; (ví dụ: một bài giảng ở trường đại học)</td></tr></tbody></table></figure><p>&nbsp;</p><h2>Cách tính điểm thi IELTS Listening</h2><figure class="table"><table><tbody><tr><td><strong>Câu trả lời đúng</strong></td><td><strong>Thang điểm</strong></td></tr><tr><td>39-40</td><td>9</td></tr><tr><td>37-38</td><td>8.5</td></tr><tr><td>35-36</td><td>8</td></tr><tr><td>32-34</td><td>7.5</td></tr><tr><td>30-31</td><td>7</td></tr><tr><td>26-29</td><td>6.5</td></tr><tr><td>23-25</td><td>6</td></tr><tr><td>18-22</td><td>5.5</td></tr><tr><td>16-17</td><td>5</td></tr><tr><td>13-15</td><td>4.5</td></tr><tr><td>11-12</td><td>4</td></tr></tbody></table></figure><h2>Mẹo luyện thi IELTS Listening hiệu quả</h2><p>Nếu bạn nghĩ rằng Nghe là kỹ khó nhất trong bài thi IELTS thì với một số người đây lại là kỹ năng giúp học tăng điểm IELTS. Dưới đây là một vài lời khuyên dành cho bạn:</p><ul><li>Bạn chỉ có một lần duy nhất để nghe bài thi IELTS, do đó, bạn phải thường xuyên luyện tập trả lời các câu hỏi và hoàn thành bài thi thử đầy đủ. Bạn có thể tìm thấy những nguồn <a href="https://ieltsmaterial.com/ielts/"><strong>tài liệu thi IELTS</strong></a> của những năm trước trên internet và bắt đầu thực hành một cách nghiêm túc.</li><li>Bạn sẽ có một phút trước mỗi phần thi để đọc câu hỏi. Hãy chắc chắn rằng bạn đã đọc cẩn thận và nắm được những gì bạn cần nghe để viết câu trả lời. Lưu ý yêu cầu số lượng từ được chỉ định trong câu trả lời, ví dụ: A date/number: câu trả lời phải là ngày hoặc số. Bên cạnh đó, bạn cũng cần chú ý khi sử dụng dấu gạch nối (hyphen) giữa 2 thành phần thì sẽ được tính là một từ và nếu không có dấu gạch nối thì sẽ được tính là 2 từ.</li><li>Tiếp theo, spelling - chính tả cũng rất quan trọng trong bài thi. Đối với những người mới bắt đầu học tiếng Anh, việc nghe đúng và viết đúng chính tả là một điều khó có thể thực hiện. Vì vậy, bạn có thể viết sai chính tả trong giấy nháp nhưng khi chuyển vào phiếu trả lời thì bạn phải chú ý ghi đúng nhé. Đặc biệt nên chú ý đến những từ số nhiều.</li><li>Cuối cùng, nhiều khả năng bạn sẽ bị bẫy thông tin trong bài nghe, do đó hãy cố gắng lắng nghe và đừng để mất tập trung vì có thể bạn sẽ bỏ lỡ thông tin quan trọng nhất, có khi đó chính là câu trả lời mà bạn đang tìm kiếm.&nbsp;</li></ul><h2>Các loại câu hỏi trong IELTS Listening</h2><p>Dưới đây là một số dạng câu hỏi thường xuất hiện trong bài thi Nghe mà bạn nên tham khảo nếu muốn giành được điểm cao:</p><p><strong>Câu hỏi trắc nghiệm:</strong></p><p>Trong bài thi IELTS Listening sẽ có một phần cho câu hỏi trắc nghiệm, thường những câu hỏi này sẽ rơi vào 1 trong 2 dạng sau:</p><ul><li>Câu hỏi trắc nghiệm có một câu trả lời&nbsp;</li><li>Câu hỏi trắc nghiệm có hai câu trả lời trở lên</li></ul><p>Đối với những câu hỏi có một hoặc nhiều câu trả lời, bạn sẽ phải lắng nghe thật kỹ để xác định tất cả các câu trả lời từ các tùy chọn được đưa ra.</p><p>Khi trả lời các câu hỏi trắc nghiệm, bạn nên ghi nhớ các điều sau:</p><ul><li>Đọc kỹ câu hỏi và đáp án, nhất là những thông tin về ngày, tháng, năm.</li><li>Thông tin được cung cấp trong bài nghe có thể không theo thứ tự các câu hỏi, vì vậy để trả lời chính xác, bạn nên đọc một lượt các câu hỏi để xác định vấn đề đang được hỏi.</li><li>Các từ sử dụng trong câu hỏi đa phần sẽ được thay thế bằng các từ đồng nghĩa trong bài nghe hoặc diễn giải bằng một cách khác.</li><li>Bài nghe sẽ đưa ra nhiều loại thông tin khiến bạn phân tâm, do đó đừng vội vàng viết ra câu trả lời ngay khi bạn nghe nó vì đôi khi đó không phải là câu trả lời chính xác.</li></ul><p><strong>Câu hỏi xác định vị trí trên bản đồ</strong></p><p>Đối với các loại câu hỏi này, bạn sẽ được cung cấp bản đồ và nhiệm vụ của bạn là tìm và gắn các địa điểm cho sẵn với vị trí trên bản đồ. Có hai dạng câu hỏi này:</p><ul><li>Một danh sách các từ cần điền được cung cấp sẵn và bạn chỉ cần nghe và chọn đúng từ phù hợp để điền vào khoảng trống trên bản đồ.</li><li>Sẽ không có danh sách nào được cho sẵn, bạn sẽ phải nghe và tự xác định địa điểm đề điền vào bản đồ.</li></ul><p>Những lưu ý giúp bạn làm tốt bài thi xác định vị trí trên bản đồ:</p><ul><li>Đọc kỹ câu hỏi để biết giới hạn số từ được điền và khoảng trống</li><li>Sẽ có chỉ dẫn đến một nơi hoặc một vài loại chuyến đi nào đó.</li><li>Lắng nghe những mô tả xung quanh địa điểm đã cho. Ví dụ: bên dưới công viên, bên cạnh siêu thị, v.v…</li><li>Nhìn vào câu hỏi và xác định hướng đi của bản đồ.&nbsp;Điều đó sẽ giúp bạn lắng nghe những gì sắp diễn ra chính xác hơn.&nbsp;</li></ul><p><strong>Loại câu hỏi: Hoàn thành câu / Hoàn thành ghi chú / Hoàn thành bảng / Câu hỏi hoàn thành sơ đồ</strong></p><p>Trong một số câu hỏi, sẽ có một khoảng trống ở giữa để bạn dự đoán và điền đáp án chính xác vào. Điều này đòi hỏi bạn phải có một nền tảng kiến thức vững chắc.</p><ul><li>Đọc câu hỏi trước khi bạn bắt đầu để hiểu những gì bạn nên lắng nghe.&nbsp;</li><li>Hãy thử đoán những gì sẽ điền trong chỗ trống. Đó có thể là một địa điểm, một số, năm, tên hoặc thậm chí là một phạm vi thông tin cụ thể (ví dụ như mùa màng, điều kiện khí hậu).</li><li>Câu trả lời phải là từ chính xác xuất hiện trong bài nghe</li><li>Kiểm tra số từ, chính tả và ngữ pháp trước khi bạn chuyển câu trả lời của mình vào phiếu trả lời nhé.</li></ul><p><strong>Câu hỏi nối thông tin</strong></p><p>Loại câu hỏi này không phổ biến như các loại câu hỏi khác nhưng thỉnh thoảng chúng vẫn xuất hiện trong phần Nghe. Đối với dạng câu hỏi này, bạn sẽ có một danh sách các câu trả lời, bạn chỉ việc nghe và nối chúng lại với nhau cho phù hợp.</p><p>Bạn nên tranh thủ nhìn vào tất cả đáp án trước khi nghe để có cái nhìn khái quát về thông tin, nếu câu trả lời là ngày, hãy lắng nghe kỹ lưỡng&nbsp; tất cả các ngày trong bài. Ngoài ra, bạn nên viết ra tất cả các thông tin liên quan để giúp bạn dễ dàng tìm thấy đáp án nhanh và chính xác hơn.&nbsp;&nbsp;</p><h2>Các cụm từ then chốt trong bài thi IELTS</h2><p>Ngôn ngữ then chốt được sử dụng như một lời giới thiệu để dẫn dắt người nghe đi đến một nội dung chi tiết. Dưới đây là danh sách những cụm từ giúp người nghe có thể dự đoán những gì sẽ diễn ra tiếp theo và tìm câu trả lời cho</p><figure class="table"><table><tbody><tr><td><strong>Mục đích</strong></td><td><strong>Các cụm từ then chốt</strong></td></tr><tr><td>Giới thiệu bài học / bài giảng</td><td><ul><li>The purpose of today’s lecture is…</li><li>The subject/topic of my talk is</li><li>The lecture will outline …</li><li>The talk will focus on …</li><li>Today I’ll be talking about / discussing…</li><li>Today we are going to talk about…</li><li>The topic of today’s lecture is…</li></ul></td></tr><tr><td>Mô tả cấu trúc của bài giảng</td><td><ul><li>I’m going to divide this talk into a few parts.</li><li>First, we’ll look at….. Then we’ll go on to … And finally I’ll…</li></ul></td></tr><tr><td>Giới thiệu chủ đề / điểm đầu tiên / phần đầu tiên</td><td><ul><li>I’m going to divide this talk into a few parts.</li><li>First, we’ll look at….. Then we’ll go on to … And finally I’ll…</li></ul></td></tr><tr><td>Bắt đầu một ý tưởng hoặc liên kết đến một ý tưởng khác</td><td><ul><li>Let’s move on to…</li><li>Now, let’s turn to…</li><li>And I’d now like to talk about…</li><li>Building on from the idea that…,</li><li>Another line of thought on … demonstrates that</li><li>Having established …,</li></ul></td></tr><tr><td>Để kết thúc cuộc nói chuyện / Tổng kết</td><td><ul><li>In conclusion, …</li><li>From the above, it is clear that …</li><li>Several conclusions emerge from this analysis …</li><li>To summarise, …I’d like now to recap…</li></ul></td></tr></tbody></table></figure><p>Hy vọng với những thông tin hữu ích trên, các bạn đã nắm được sơ lược về cấu trúc đề thi IELTS Listening và các mẹo giúp bạn luyện thi hiệu quả. Chúc các bạn đạt được số điểm như mong đợi trong kỳ thi IELTS của mình.</p>	 	2023-06-29 09:10:54.105	2023-06-29 09:10:54.105
310	205	1	Phụ âm /ʒ/	2		0	0	<p><br><img src="http://res.cloudinary.com/doxsstgkc/image/upload/v1688030174/examify/image_hiezyr.png"></p><p><strong>Để phát âm phụ âm /ʒ/:</strong></p><p>Đặt đầu lưỡi ở hàm trên, phía sau nơi đặt lưỡi để phát âm âm /s/. Rung dây thanh quản khi bạn đẩy luồng hơi vào giữa hai hàm răng và đầu lưỡi.</p><p>Sử dụng các đoạn ghi âm và nút “play” sau đây để so sánh cách phát âm của bạn với các từ bên dưới:</p><p>measure</p><p>decision</p><p>massage</p><p>usually</p><p><strong>Trong từ</strong></p><p>Âm /ʒ/ đóng một vai trò quan trọng về sự khác biệt giữa cặp từ dưới đây.</p><p>Nghe từng cặp, chú ý xem từ đầu tiên khác với từ thứ hai như thế nào.</p><p>leach | liege</p><p>virgin | version</p><p>composer | composure</p><p>Ghi âm lại mỗi khi bạn phát âm các từ, đảm bảo tập trung vào cách phát âm của âm /ʒ/. Sau đó, so sánh đoạn ghi âm của bản thân với đoạn ghi âm mẫu. Nếu bạn cần trợ giúp, hãy xem video để biết cách phát âm chính xác âm /ʒ/.</p><p>Lặp lại bài tập này vài lần một ngày. Như việc học bất kỳ kỹ năng nào, việc cải thiện và tiến bộ cần sự lặp đi lặp lại và luyện tập.</p><p>Dưới đây là một số từ phổ biến có chứa âm /ʒ/. Hãy cảm thấy thoải mái với cách phát âm của những từ này.</p><p>Nghe cách phát âm của từng từ, tập trung vào âm /ʒ/. Chú ý việc âm /ʒ/ có thể xuất hiện ở đầu, giữa hoặc cuối từ.</p><p>vision</p><p>fusion</p><p>leisure</p><p>garage</p><p>inclusion</p><p>Ghi âm lại bản thân mỗi khi lặp lại việc phát âm các từ, đảm bảo tập trung vào cách phát âm của âm /ʒ/. So sánh đoạn ghi âm của bản thân với đoạn ghi âm mẫu. Lặp lại bài tập này vài lần một ngày.</p><p><strong>Trong câu</strong></p><p>Điều quan trọng trong luyện tập phát âm là phải vượt ra khỏi các từ đơn lẻ khi bạn luyện âm trong tiếng Anh. Phương pháp sử dụng các câu nói líu lưỡi (tongue twisters) là một cách tuyệt vời để luyện tập lưỡi của bạn trong việc phát âm âm /ʒ/ trong câu nói liền mạch.</p><p>Lắng nghe cách các câu nói líu lưỡi được phát âm. Hãy nhớ ghi chú những âm hoặc từ có thể gây khó khăn cho bạn và số lần bạn phát âm âm /ʒ/.</p><p>Usually leisure is measured in massages.</p><p>Don't sabotage my treasure. Don't sabotage my treasure. Don't sabotage my treasure.</p><p>A camouflage corsage was on the collage.</p><p>This genre is usually a pleasure.</p><p>Ghi âm lại bản thân mỗi lần lặp lại các câu nói líu lưỡi. Hãy thử với tốc độ chậm trước, sau đó tăng dần đến tốc độ trôi chảy, tự nhiên.</p><p>Lặp lại bài tập này vài lần một ngày. Bạn cũng có thể thử tạo ra những câu nói líu lưỡi của riêng mình!</p><p>Luyện phát âm thậm chí còn hiệu quả hơn trong ngữ cảnh có nghĩa. Dưới đây là một số câu chứa âm /ʒ/&nbsp;mà bạn có thể thấy mình thường xuyên nói trong giao tiếp hàng ngày.</p><p>Nghe cách phát âm từng câu. Những từ nào có chứa âm /ʒ/?</p><p>It's a pleasure to meet you.</p><p>It's a difficult decision.</p><p>Ghi âm lại bản thân mỗi khi lặp lại từng câu, tập trung vào cách phát âm của âm /dʒ/. Lặp lại bài tập này vài lần một ngày.</p>	 	2023-06-29 09:16:23.008	2023-06-29 09:16:23.008
311	205	2	Âm đuôi -s	2		0	0	<p>Nghe ba từ sau đây. Bạn có nhận thấy bất kỳ sự khác biệt nào trong âm đuôi <i>-s</i>&nbsp;của từ hay không?</p><p>books</p><p>bags</p><p>changes</p><p>Nếu bạn đã nghe một cách cẩn thận, bạn có thể nhận thấy rằng mỗi từ có một âm đuôi <i>-s </i>khác nhau. Đó là bởi vì trong tiếng Anh, có ba cách khác nhau để phát âm âm đuôi <i>-s</i>.</p><p><strong>Luyện tập 1</strong></p><p>Nghe các nhóm từ sau đây và xem liệu bạn có thể xác định âm đuôi <i>-s</i>&nbsp;của mỗi nhóm là gì hay không. Sau đó, cố gắng tìm một quy tắc để giải thích cách phát âm âm đuôi <i>-s</i>&nbsp;cho mỗi nhóm:</p><p><strong>1. Nhóm 1</strong></p><p>thinks</p><p>it's</p><p>ships</p><p>laughs</p><p>appreciates</p><p><strong>Quy tắc</strong></p><p>Nếu một từ kết thúc bằng âm vô thanh thì đuôi <i>-s</i>&nbsp;sẽ phát âm giống như âm <strong>/s/</strong>. Hãy chắc chắn rằng dây thanh quản của bạn không rung bằng cách đặt tay lên cổ họng. Bạn sẽ không cảm thấy độ rung khi phát âm âm <strong>/s/</strong>.</p><p><strong>2. Nhóm 2</strong></p><p>phones</p><p>explains</p><p>Carla's</p><p>exams</p><p>theirs</p><p><strong>Quy tắc</strong></p><p>Nếu một từ kết thúc bằng âm hữu thanh thì đuôi <i>-s</i>&nbsp;sẽ phát âm giống như âm <strong>/z/</strong>. Hãy chắc chắn rằng dây thanh quản của bạn <strong>có rung </strong>bằng cách đặt tay lên cổ họng. Bạn sẽ cảm thấy độ rung khi phát âm âm <strong>/z/</strong>.</p><p><strong>3. Nhóm 3</strong></p><p>catches</p><p>Chris's</p><p>ages</p><p>analyzes</p><p>washes</p><p><strong>Quy tắc</strong></p><p>Nếu một từ kết thúc bằng âm rít như âm /<strong>s/</strong>, /<strong>z/</strong>, /<strong>t͡ʃ/</strong>, /<strong>d͡ʒ/</strong>, /<strong>ʃ/</strong>, hoặc /<strong>ʒ/</strong>, thì đuôi <i>-s</i>&nbsp;sẽ phát âm giống như âm /<strong>əz/</strong>. Lưu ý rằng đây là âm đuôi <i>-s</i>&nbsp;duy nhất có phát âm thêm một âm tiết.</p>	 	2023-06-29 09:17:03.871	2023-06-29 09:17:03.871
312	206	1	Cụm từ diễn tả ý tưởng và ngắt nghỉ	2		0	0	<p>Cụm từ diễn tả ý tưởng là một khía cạnh khác của nhịp điệu trong tiếng Anh nói có thể có lợi cho khả năng nghe hiểu của bạn. Các cụm từ diễn tả ý tưởng cho phép bạn sắp xếp bài nói của mình thành các nhóm từ để tạo nên một ý tưởng duy nhất (Grant, 2010). Chúng giúp người nghe hiểu rõ hơn về thông tin trong bài nói của bạn bằng cách sắp xếp các ý tưởng của bạn thành các “cụm” để dễ hiểu hơn. (Grant, 2010).</p><p>Hãy nghe các ví dụ sau đây. Câu đầu tiên không sử dụng cụm từ diễn tả ý tưởng, trong khi câu thứ hai thì có sử dụng:</p><p>The only thing I'm interested in is completing this project on time.</p><p>The only thing I'm interested in is completing this project on time.</p><p>Câu thứ hai được chia thành hai cụm từ diễn tả ý tưởng, với một khoảng ngắt nghỉ rất ngắn ở giữa. Mỗi cụm từ diễn tả ý tưởng trong tiếng Anh cũng có một <strong>từ được nhấn mạnh</strong>&nbsp;(focus word) duy nhất, thường là từ chỉ nội dung cuối cùng trong cụm từ diễn tả ý tưởng. Từ nhấn mạnh nhất thường có trọng âm mạnh hơn so với các từ khác trong câu. Từ được nhấn mạnh trong cụm từ diễn tả ý tưởng đầu tiên ở ví dụ trên là “<i>interested</i>”; trong cụm từ diễn tả ý tưởng thứ hai, từ được nhấn mạnh là “<i>time</i>”. (Lưu ý: Đôi khi các cụm từ diễn tả ý tưởng có thể chỉ chứa một từ, như trong ví dụ này.)</p><p>First, check to make&nbsp;sure that your seat belt is&nbsp;secure.</p><p>Câu trên gồm 3 cụm từ diễn tả ý tưởng và 3 từ được nhấn mạnh.</p><p>Các cụm từ diễn tả ý tưởng có thể đặc biệt hữu ích trong các bài thuyết trình, bài phát biểu, tranh luận và các bối cảnh phải nói trước công chúng khác, nhưng việc tạo các cụm từ diễn tả ý tưởng sẽ cải thiện mức độ dễ hiểu của bạn trong cả các cuộc hội thoại thường ngày và các bài phát biểu trang trọng.</p><p>Thoạt đầu, có thể không dễ dàng xác định ranh giới giữa các cụm từ diễn tả ý tưởng. Nếu bạn đã từng đọc to một đoạn văn bản, có thể bạn đã nhận thấy cách một số loại dấu câu (dấu phẩy, dấu chấm phẩy, dấu ngoặc kép, v.v.) có thể phân tách các cụm từ diễn tả ý tưởng với nhau. Tuy nhiên, các cụm từ diễn tả ý tưởng không phải lúc nào cũng được phân tách nhau bằng các dấu câu (như trong câu “<i>The only thing I'm interested in is completing this project on time</i>”). Ngoài ra, không phải tất cả câu nói nào cũng sẽ được viết hẳn ra. Các cụm từ diễn tả ý tưởng là một đặc tính của văn nói và được chuyển thành văn bản viết với các dấu câu.</p><p>Cuối cùng, hãy nhớ rằng một câu có thể được chia thành các cụm từ diễn tả ý tưởng khác nhau, do đó ảnh hưởng đến ý nghĩa của cả câu. Hãy xem xét ví dụ này:</p><p>Woman without her man is nothing.</p><p>Câu này có nghĩa là gì? Tùy thuộc vào cách bạn phân chia các cụm từ diễn tả ý tưởng, ý nghĩa câu có thể thay đổi (trong ví dụ trên thì là một sự thay đổi rất đáng kể).</p><p>Woman/ without her/ man is nothing.</p><p>Woman without her man/ is nothing.</p><p>Như ví dụ này đã minh họa, cụm từ diễn tả ý tưởng là một công cụ giúp bạn truyền đạt rõ ràng ý định của mình, không phải là điều bạn cần phải “tìm thấy” trong mỗi câu bạn muốn nói. Những người nói khác nhau có thể và chắc chắn sử dụng các cụm từ diễn tả ý tưởng khác nhau.</p>	 	2023-06-29 09:18:10.826	2023-06-29 09:18:10.826
313	207	1	Từ vựng theo chủ đề phần 1	3		0	21		 	2023-06-29 09:33:44.167	2023-06-29 09:33:44.167
314	207	2	Từ vựng theo chủ đề phần 2	3		0	22		 	2023-06-29 09:34:01.984	2023-06-29 09:34:01.984
315	208	1	Present tenses: present simple; present continuous; state verbs; there is/ there are	1	https://www.youtube.com/watch?v=XvjC23LTsFE&ab_channel=STUDY4	0	0		 1. Hiện tại đơn (present simple)\n(+) verb/verb + (e)s            She plays volleyball.\n\n(-) do/does not + verb        She doesn’t play volleyball.\n\n(?) do/does … + verb?       Do you play volleyball?\n\nChúng ta sử dụng thì hiện tại đơn để:\n\nNói về thói quen thường ngày hoặc những hành động lặp đi lặp lại\nEg: He gets up at 6 a.m and eats sandwiches for breakfast most days.\n\nAnh ấy dậy vào lúc 6 giờ sáng và ăn sáng với bánh mì kẹp gần như mỗi ngày.\n\nEg: I play sports just about everyday.\n\nTôi chơi thể thao gần như mỗi ngày.\n\nLưu ý: Những từ mô tả về tần suất và thời điểm thường dùng: always, generally, normally, usually, often, sometimes, rarely, never, everyday, every evening\nNói về một tình huống cố định, thường trực:\nEg: My brother owns a hotel.\n\nAnh tôi sở hữu một khách sạn.\n\nLưu ý: Chúng ta sử dụng hiện tại hoàn thành, không phải hiện tại đơn khi nói về một hành động đã tiếp diễn trong bao lâu\nEg: We have worked there since last year. (not we work there since last year)\n\nChúng tôi đã làm việc ở đây từ năm ngoái\n\nNói về sự thật được hầu hết mọi người chấp nhận, chân lý luôn đúng:\nEg: The sun rises in the east and sets in the west. \n\nMặt trời mọc ở phía Đông và lặn ở phía Tây.\n\nEg: Children generally like eating sweets.\n\nTrẻ con thường thích ăn kẹo.\n\nLưu ý:Những từ sau thường được sử dụng diễn tả sự thật được hầu hết mọi người chấp nhận: generally, mainly, normally, usually, traditionally\nĐưa ra chỉ dẫn:\nEg: You turn left at the right corner and then go straight.\n\nBạn rẽ trái ở góc bên phải và sau đó đi thẳng.\n\nEg: To open this file, you double click the icon.\n\nĐể mở tệp này bạn nháy đúp chuột vào biểu tượng.\n\nKể chuyện và nói về nội dung phim, sách, vở kịch:\n \n\n\n\nEg: In the book, the girl falls in love with a vampire. \n\nTrong cuốn sách này, cô gái yêu một ma cà rồng.\n\n2. Hiện tại tiếp diễn (present continuous)\n(+) am/is/are + verb + -ing           He’s living in Singapore.\n\n(-) am/is/are + verb + -ing            I am not living in Singapore.\n\n(?) am/is/are… + verb + -ing?     Are they living in Singapore?\n\nChúng ta sử dụng thì hiện tại tiếp diễn để:\n\nNói về những tình huống tạm thời:\nEg: They are practicing for the performance. \n\nHọ đang tập luyện cho màn trình diễn.\n\nEg: My friend is having a holiday at the moment. \n\nỞ thời điểm hiện tại, bạn tôi đang trong kỳ nghỉ.\n\nLưu ý: Những từ như at the moment, currently, now, this week/month/year thường được sử dụng.\nNói về hành động diễn ra tại thời điểm nói:\nEg: He is speaking on the phone.\n\nAnh ấy đang nói chuyện điện thoại.\n\nNói về xu hướng hoặc tình huống đang thay đổi:\nEg: The weather is getting worse and worse. \n\nThời tiết đang ngày càng xấu đi.\n\n \n\n\n\nEg: The price of petrol is rising dramatically.\n\nGiá xăng đang tăng chóng mặt.\n\nNói về những hành động diễn ra thường xuyên hơn mong đợi, thường thể hiện thái độ ghen tỵ hay phàn nàn, chỉ trích, với các từ always, constantly, continually, forever\nEg: You are always taking my stuff without asking!\n\nEm lúc nào cũng lấy đồ của chị mà không hỏi thế! (phàn nàn)\n\nEg: She is always dining at fancy restaurants every week! \n\nCô ấy luôn ăn tối tại những nhà hàng sang chảnh vào mỗi tuần! (ghen tỵ)\n\n3. Động từ tình thái (state verbs)\nHiện tại tiếp diễn không thường được sử dụng với động từ tình thái vì những từ này bản thân mang nghĩa chỉ sự thật, trạng thái, tính chất hơn là những sự việc, hành động mang tính tạm thời. Những động từ này miêu tả suy nghĩ, cảm xúc, cảm giác từ các giác quan, sự sở hữu và sự mô tả.\n\nDưới đây là 1 số ví dụ về động từ tình thái:\n\nSuy nghĩ: agree, asume, believe, disagree, forget, hope, know, regret, remember, suppose, think, understand\nEg: Do you suppose (that) he will come? \n\nCô có nghĩ là anh ta sẽ đến không?\n\nCảm xúc: adore, desire, dislike, enjoy, feel, hate, like, love, mind, prefer, want\nEg: Do you mind if I close the window?\n\nAnh có phiền không nếu tôi đóng cửa sổ lại?\n\nGiác quan: feel, hear, see, smell, taste\nEg: This cake tastes delicious! \n\nCái bánh này ngon thật!\n\nLưu ý: Để nói về những hành động đang diễn ra, chúng ta sử dụng can:\nEg: I can hear someone screaming.\n\nTôi có thể nghe thấy ai đó đang hét.\n\nSự sở hữu: have, own, belong\n\n\nEg: My friend has a collection of dolls in her room. \n\nBạn tôi có bộ sưu tập búp bê trong phòng cô ấy.\n\nSự mô tả: appear, contain, look, look like, mean, resemble, seen, smell, sound, taste, weigh\nEg: He appears to be a kind person.\n\nAnh ấy có vẻ là một người tốt bụng (1 trạng thái cố định chứ không phải tạm thời)\n\nLưu ý: Một số động từ tình thái có thể sử dụng trong cấu trúc tiếp diễn khi mang nghĩa nói về một hành động đang xảy ra (mang tính tạm thời). \nEg: What is she thinking about? \n\nCô ấy đang nghĩ gì vậy? (từ “think” được dùng để nói về hành động “suy nghĩ” ở thời điểm nói, mang tính tạm thời)\n\n       I think you should take the doctor's advice and give up smoking. \n\n       Tôi nghĩ cậu nên nghe theo lời khuyên của bác sĩ và bỏ hút thuốc đi. (từ “think” được dùng để nêu ý kiến)  \n\nEg: I’m smelling the milk to see if it is spoiled or not. \n\nTôi đang ngửi xem chỗ sữa này có bị hỏng hay không. (từ “smell” được dùng để nói về hành động “ngửi ở thời điểm nói, mang tính tạm thời)\n\n      The toilet smells horrible.\n\n      Nhà vệ sinh này có mùi thật kinh khủng. (từ “smell” được dùng để miêu tả trạng thái của sự vật)\n\nEg: He’s having lunch at a nearby restaurant. \n\nAnh ấy đang ăn trưa ở nhà hàng ngay gần đây. (từ “have” được dùng để nói về hành động “ăn” ở thời điểm nói, mang tính tạm thời)\n\n      To be honest, I don’t have much money.\n\nNói thật là tôi không có nhiều tiền. (từ ‘have” mang nghĩa “sở hữu”, mang tính cố định)\n\n4. Cấu trúc There is/ There are\nChúng ta sử dụng there để nói rằng điều gì đó tồn tại. Chúng ta sử dụng there is với chủ ngữ số ít và there are với chủ ngữ số nhiều:\nEg: There is an oak tree in my garden. \n\nCó một cây gỗ sồi ở vườn nhà tôi.  (không phải It is an oak tree hoặc There have an oak tree)\n\n            There are some great movies at the cinema. \n\nCó một số bộ phim hay đang chiếu ở rạp. (không phải They are some great movies)\n\nChúng ta sử dụng there is và there are để đưa thông tin mới. Chúng ta sử dụng it is hoặc they are để nói về một điều gì đó đã được nhắc đến trước đó. So sánh:\nEg: There is a present for you on the table.\n\nCó một món quà cho bạn ở trên bàn. (lần đầu món quà được nhắc đến)\n\n  Mary: What is that you're carrying?\n\nCậu đang mang gì đấy?\n\n John: It's a present for my sister.\n\nĐây là món quà cho em gái mình. (it: thứ mà John đang mang).\n\nChúng ta không sử dụng trợ động từ do để đặt câu hỏi và câu phủ định với there is và there are:\n\n\nEg: Are there any clean glasses in the cupboard?\n\nCó chiếc ly sạch nào trong tủ bếp không?\n\n      There isn't a map in the car.\n\nKhông có tấm bản đồ nào ở trên xe.\n\nThere không thể bị lược bỏ: \nEg: There is a pan of soup and there are some bowls in the kitchen.\n\nCó một chảo súp và một vài chiếc bát ở trong bếp. (không phải There is a-pan of soup are some bowls in the kitchen.	2023-06-29 09:36:27.276	2023-06-29 09:36:27.276
316	208	2	Past tenses 1: past simple, past continuous, used to, would	1	https://www.youtube.com/watch?v=PKMb2gjJJxY&ab_channel=STUDY4	0	0		 1. Quá khứ đơn (past simple)\n(+) verb + -ed (hoặc -d)      She worked as a teacher.\n\n(-) did not + verb                 He didn’t work as a teacher.\n\n(?) did… + verb?                 Did they work as teachers?\n\nLưu ý: Động từ bất quy tắc\nNhiều động từ có dạng bất quy tắc: went (go), wrote (write)\n\nLưu ý rằng động từ “be” là động từ bất quy tắc: I/he/she/it + was; you/we/they + were.\n\nChúng ta sử dụng thì quá khứ đơn để:\n\nNói về những hành động đơn lẻ đã hoàn thành trong quá khứ, thường có nhắc đến thời điểm cụ thể. \nEg: I called my mom yesterday. \n\nTôi đã gọi cho mẹ ngày hôm qua.\n\nLưu ý: Nếu thời gian đã được nhắc đến trước đó thì không cần nhắc lại nữa:\nEg: How could she know that I was sad? \n\nSao mẹ lại biết tôi buồn nhỉ? (thời điểm được nhắc đến trong câu chuyện đã kể trước đó)\n\nNói đến một chuỗi hành động lần lượt theo thứ tự xảy ra trong quá khứ:\n\n\nEg: I hung up the phone, turned off the light and went to sleep.\n\nTôi gác máy, tắt đèn và đi ngủ. \n\nLưu ý: Chúng ta thường dùng những từ next, then để chỉ thứ tự của chuỗi sự việc:\nEg: Then, I suddenly felt hungry. \n\nSau đó, tôi đột nhiên cảm thấy đói. \n\nNói về những hành động lặp đi lặp lại trong quá khứ:\nEg: She often went to school at 7:30 a.m when she was a student. \n\nCô ấy thường đi học vào lúc 7h30 khi cô ấy còn là học sinh.\n\nLưu ý rằng used to và would cũng có thể được sử dụng.\n\nNói về những tình huống kéo dài trong quá khứ nhưng không còn đúng ở hiện tại:\nEg: People once believed that the Sun revolved around the Earth. \n\nMọi người từng tin rằng Mặt trời xoay quanh Trái đất.\n\nLưu ý rằng used to cũng có thể được sử dụng.\n\nEg: People used to believe that the Sun revolved around the Earth. \n\nMọi người từng tin rằng Mặt trời xoay quanh Trái đất.\n\n2. Quá khứ tiếp diễn (past continuous)\n(+) was/were + verb + -ing             He was listening to music.\n\n(-) was/were not + verb + -ing       We weren’t listening to music.\n\n(?) was/were … + verb + -ing        Were you listening to music?\n\nChúng ta sử dụng thì quá khứ tiếp diễn để:\n\nCung cấp hoàn cảnh của một hành động hoặc sự kiện (thường ở thì quá khứ đơn). Chúng ta thường sử dụng những từ như when, while, as:\nEg: We were watching TV when the phone rang.\n\nChúng tôi đang xem ti vi thì điện thoại kêu.\n\nEg: The accident happened while the people were waiting for the traffic light. \n\nTai nạn xảy ra khi mọi người đang chờ đèn đỏ.\n\nLưu ý: hành động dài hơn được chia ở thì quá khứ tiếp diễn, hành động/ sự việc đột nhiên diễn ra (ngắn hơn) được chia ở thì quá khứ đơn. \nĐề cập đến 2 sự việc/ hành động xảy ra cùng một lúc:\n\n\n\nEg: She was doing the dishes and listening to the music. \n\nCô ấy vừa rửa bát vừa nghe nhạc.\n\nNhấn mạnh hành động diễn ra trong một khoảng thời gian ở quá khứ mà không tập trung vào sự hoàn thành của hành động đó:\nEg: For a while last year, I was studying for my IELTS test, working at a cafe shop and finishing my college degree. \n\nTrong 1 khoảng thời gian vào năm ngoái, tôi ôn thi IELTS, làm việc tại quán cà phê và hoàn thành bằng cao đẳng của mình. (việc các hành động đã hoàn thành hay chưa đều không rõ và các hành động có thể diễn ra cùng lúc trong khoảng thời gian đó)\n\nEg: Last year, I studied for my IELTS test, worked at a cafe shop and finished my college degree.\n\nNăm ngoái, tôi đã ôn thi IELTS, làm việc tại quán cà phê và hoàn thành bằng cao đẳng của mình. (các hành động đều đã hoàn thành và có thể diễn ra theo đúng thứ tự được kể)\n\nLưu ý: Động từ tình thái (xem Unit 1) thường không có dạng tiếp diễn.\n3. Used to và would\n(+) used to/would + infinitve             He used to/ would go swimming. \n\n(-) did not + use to + infinitive          We didn't use to go swimming.\n\n(?) Did... + use to + infinitive?          Did they use to go swimming?\n\nChúng ta dùng used to + infinitive hoặc would + infinitive (viết tắt là ‘d thường được dùng trong văn nói) để nói về những hành động lặp đi lặp lại, thói quen trong quá khứ.\n\n\nEg: He used to like drinking soda.\n\nAnh ấy từng thích uống soda. (giờ không còn thích nữa)\n\nEg: He would drink soda whenever he had meals.\n\nAnh ấy từng uống soda mỗi khi dùng bữa. (bây giờ không uống nữa)\n\nLưu ý: Would ít khi dùng ở dạng phủ định và câu hỏi Yes/No\nChúng ta sử dụng used to + infinitive để nói về những tình huống cố định nhưng không còn đúng ở hiện tại:\nEg: Harry used to be a teacher at a local high school.\n\nHarry từng là giáo viên ở một trường cấp 3 địa phương. (nhưng bây giờ không còn làm nữa)\n\nChúng ta không sử dụng used to khi muốn nói tình huống kéo dài trong bao lâu:\n\nEg: Harry was a teacher at a local high school for 5 years. \n\nAnh ấy đã từng làm giáo viên ở một trường cấp 3 địa phương trong 5 năm.\n\nLưu ý: Chúng ta không sử dụng would với động từ tình thái.\n4. Phân biệt cấu trúc used to với be used to và get used to\n4.1. Be used to: đã quen với việc / cái gì đó (có thể dùng ở cả thì quá khứ và hiện tại và tương lai ~ chia động từ "be")\n(+) S + be + used to + V-ing/danh từ.\n\n(-) S + be + not used to + V-ing/danh từ.\n\n(?) Be + S +  used to + V-ing/danh từ?\n\nE.g.\n\nKhẳng định (+):\n\nI am used to being lied to.\n           Tôi đã quen với việc bị nói dối rồi.\n\nHe is used to working late.\n           Anh ấy đã quen với việc làm việc muộn.\n\nPhủ định (-): \n\nHe wasn’t used to the heat and he caught sunstroke.\n           Anh ấy không quen với cái nóng và bị bỏng nắng.\n\nWe aren’t used to taking the bus\n           Chúng tôi không quen với việc đi xe bus.\n\nNghi vấn (?):\n\nIs she used to cooking?\n           Cô ấy có quen với việc nấu ăn không?\n\nAre you used to fast food?\n          Bạn có quen ăn đồ ăn nhanh không?\n\n4.2. Get used to: dần làm quen với việc/ cái gì đó (có thể dùng ở cả thì quá khứ và hiện tại và tương lai ~ chia động từ "get")\n(+) S + get used to + V-ing/danh từ.\n\n(-) S + do not get used to + V-ing/danh từ.\n\n(?) Do + S + get used to + V-ing/danh từ?\n\nKhẳng định (+):\n\nYou might find it strange at first but you will soon get used to it.\n           Bạn có thể cảm thấy lạ lẫm lúc đầu nhưng rồi bạn sẽ quen với điều đó.\n\nAfter a while Jane didn’t mind the noise in the office; she got used to it. \n          Sau một thời gian Jane đã không còn cảm thấy phiền bởi tiếng ồn nơi công sở. Cô ấy đã quen với nó.\n\nPhủ định (-): \n\nHe couldn't get used to working such long hours when he started his new job\n           Anh ấy từng không thể làm quen với việc làm việc trong thời gian dài khi mới bắt đầu công việc.\n\nWe couldn’t get used to the noisy neighborhood, so we moved\n           Chúng tôi đã không thể quen với tiếng ồn của hàng xóm, vậy nên chúng tôi chuyển đi.\n\nNghi vấn (?):\n\nHas your sister got used to his new boss?\n          Em gái của bạn đã quen với sếp mới chưa?\n\nHas Tom got used to driving on the left yet?\n          Tom đã quen với việc lái xe bên tay trái chưa?\n\nLưu ý\n1. Cả hai cấu trúc be used to và get used to đều theo sau bởi danh từ hoặc danh động từ (động từ đuôi -ing) # Cấu trúc used to + động từ nguyên mẫu. \n\n2. Be used to và get used to có thể được dùng ở tất cả các thì, chia động từ phù hợp cho từng thì # Cấu trúc used to chỉ dùng ở quá khứ. 	2023-06-29 09:37:21.379	2023-06-29 09:37:21.379
317	208	3	Present perfect: present perfect simple and continuous	1	https://www.youtube.com/watch?v=rpAsSnyy_fE&ab_channel=STUDY4	0	0		 Chúng ta sử dụng thì hiện tại hoàn thành khi chúng ta muốn thể hiện sự liên kết giữa hiện tại và quá khứ.\n\n1. Hiện tại hoàn thành đơn (present perfect simple)\n(+) have/has + past participle             He has finished the assignments.\n\n(-) have/has + NOT + past participle              I have not (haven’t) finished the assignments.\n\n(?) have/has … + past participle?      Have you finished the assignments?\n\nChúng ta sử dụng thì hiện tại hoàn thành đơn để:\n\nNói về sự việc xảy ra trong một khoảng thời gian chưa kết thúc (e.g. today, this week):\nEg: I have finished cleaning my room this afternoon. \n\nTôi vừa hoàn thành việc dọn phòng vào chiều nay (hiện tại vẫn đang là buổi chiều)\n\nNói về hành động xảy ra ở một thời điểm nào đó trước hiện tại và không đề cập đến thời điểm diễn ra:\nEg: She has prepared carefully for the exam. \n\nCô ấy đã chuẩn bị kỹ càng cho bài kiểm tra.\n\nNhững từ chỉ thời gian như sau thường được sử dụng: ever, never, before, up to now, still, so far, by far.\n\nEg: It’s by far the most difficult exam she's ever taken. \n\nĐây là bài kiểm tra khó nhất cô ấy từng làm từ trước đến nay (ở bất kỳ thời điểm nào trước hiện tại)\n\nLưu ý: Nếu chúng ta nói đến hành động đã diễn ra tại một thời điểm cụ thể trong quá khứ thì cần dùng thì quá khứ đơn:\nEg: She spent a lot of time studying last week. (not She's spent a lot of time studying last week.)\n\nCô ấy đã dành nhiều thời gian để học vào tuần trước.\n\nNói về tình huống ở hiện tại nhưng bắt đầu ở quá khứ, đi kèm với for/since:\nEg: She has studied hard for the last few weeks. \n\nCô ấy đã học chăm chỉ trong suốt mấy tuần nay.\n\nLưu ý: Chúng ta sử dụng for với khoảng thời gian (Eg: for two hours, for three days, for six months) và since với mốc thời gian (Eg: since 2001, since Monday, since ten o’clock, since I was four, since I started the course).\nNói về những hành động xảy ra ở thời điểm không xác định trong quá khứ nhưng có liên quan đến hiện tại:\n\n\nEg: He has watched all the films on the list. \n\nAnh ấy đã xem hết những bộ phim trong danh sách rồi.\n\nLưu ý: Những từ chỉ thời gian sau thường được sử dụng trong thì hiện tại hoàn thành: recently, just, already, và yet. Riêng từ yet thì sử dụng trong câu phủ định và câu hỏi.\nEg: I've just finished it.\n\nTôi vừa mới làm xong.\n\nEg: Have you booked the table for dinner yet? \n\nCậu đã đặt bàn cho bữa tối chưa?\n\nSo sánh giữa hiện tại hoàn thành và quá khứ đơn:\n\nHiện tại hoàn thành\n\nQuá khứ đơn\n\nLiên hệ quá khứ đến hiện tại:\nEg: I have read lots of books on that topic. \n\nTôi đã đọc rất nhiều sách về chủ đề đó. (ở một điểm nào đó trước hiện tại và có thể đọc tiếp)\n\nChỉ nói đến hành động trong quá khứ:\nEg: I read a book on that topic last month. \n\nTôi đã đọc một cuốn sách về chủ đề đó vào tháng trước. (đã đọc xong)\n\nKhông đề cập đến thời gian cụ thể ở quá khứ:\nEg: Have you seen my dog?\n\nCậu đã trông thây con chó của tớ chưa? (thời điểm nào đó trước hiện tại)\n\nĐề cập đến thời gian cụ thể trong quá khứ, hoặc thời gian đã được nhắc đến trước đó\nEg: I saw your dog when I was running in the park.\n\n Tớ đã trông thấy con chó của cậu khi mà tớ đang chạy bộ trong công viên. (hiện tại tớ đang không ở công viên và việc trông thấy con chó đã kết thúc.)\n\nSử dụng những từ chỉ khoảng thời gian chưa kết thúc:\nEg: He has been late for work 3 times this week. \n\nAnh ấy đã đi muộn 3 lần trong tuần này. (tuần này chưa kết thúc)\n\nSử dụng những từ chỉ khoảng thời gian đã kết thúc:\nEg: He was late for work 3 times last week. \n\nAnh ấy đã đi muộn 3 lần trong tuần trước. (tuần trước đã kết thúc)\n\n \n\nLưu ý đến vị trí của những trạng từ chỉ thời gian sau đây khi sử dụng trong hiện tại hoàn thành\n\nỞ giữa trợ động từ và động từ chính (Eg: recently, already, always, ever, just, never)\nEg: I have already finished my essay. \n\nTôi đã hoàn thành xong bài luận.\n\nEg: I have just started writing my essay. \n\nTôi vừa bắt đầu viết bài luận.\n\nEver thường dùng ở câu hỏi và câu phủ định:\n\n\n\nEg: Have you ever visited Korea? \n\nCậu đã đến Hàn Quốc bao giờ chưa?\n\nSau động từ chính (Eg: all my life, every day, yet, before, for, ages, for two weeks, since 2003, since I was a child,...)\nEg: I have felt depressed for days. \n\nTôi đã cảm thấy trầm cảm mấy ngày nay rồi.\n\nEg: She hasnt cooked before. \n\nCô ấy chưa từng nấu ăn trước đây.\n\nNếu có mệnh đề tân ngữ (theo sau động từ) thì từ chỉ thời gian nằm ở cuối câu:\n\nEg: My mother has complained about the dishwasher since I bought it.\n\nMẹ tôi phàn nàn về máy rửa bát từ lúc tôi mua nó về. \n\n2. Hiện tại hoàn thành tiếp diễn (present perfect continuous)\n(+) have/has been + verb + -ing           I have been studying for the exam.\n\n(-) have/has not been + verb + -ing     She hasn’t been studying for the exam.\n\n(?) have/has… been + verb + -ing?     Have you been studying for the exam?   \n\nChúng ta sử dụng hiện tại hoàn thành tiếp diễn hoặc hiện tại hoàn thành đơn để nói về việc hành động đã diễn ra trong bao lâu (sử dụng với since hoặc for)\n\nEg: I have felt depressed for months.\n\nI have been feeling depressed since I started working on this project.\n\nI have work on this project since January.\n\nI have been working on this project for 3 months. \n\nSo sánh cách sử dụng của hiện tại hoàn thành đơn và hiện tại hoàn thành tiếp diễn:\n\nHiện tại hoàn thành tiếp diễn\n\nHiện tại hoàn thành đơn\n\nNhấn mạnh về khoảng thời gian bao lâu\nEg: He has been cycling to work for the past two weeks. \n\nAnh ấy đã đi xe đạp đến chỗ làm 2 tuần qua.\n\nĐề cập đến số lần:\nEg: He has cycled to work three times. \n\nAnh ấy đã đạp xe đi làm 3 lần rồi.\n\nTập trung vào bản thân hành động (không thể hiện rằng hành động đã hoàn thành hay chưa)\nEg: She has been reading her new book. \n\nCô ấy đang đọc quyển sách mới. (chưa biết việc đọc đã xong hay chưa)\n\nTập trung vào kết quả và sự hoàn thành của hành động\nEg: She has read her new book.\n\nCô ấy đọc xong quyển sách mới của mình. (đã đọc xong nhưng không biết khi nào)\n\n \n\nLưu ý: Động từ chỉ tình thái (xem Unit 1) thường không có dạng tiếp diện:\n\n\nEg: I have loved watching horror movies since I was 15. (not I have been loving...)\n\nTôi đã thích xem phim kinh dị từ lúc tôi 15 tuổi.\n\nGrammar extra 1: This is the first time…\nChúng ta sử dụng hiện tại hoàn thành với cấu trúc sau:\n\nit/this/that is the first/ the second/ the best/ the only/ the worse …\n\nEg: It’s the first time I’ve ever visited Korea. \n\nĐây là lần đầu tiên tôi đến Hàn Quốc.\n\nEg: Is this the only time you’ve tried bungee jumping? \n\nĐây là lần duy nhất cậu thử nhảy bungee à?\n\nEg: That’s the fifth cigarette you’ve smoked today. \n\nĐây là điếu thuốc thứ 5 cậu hút hôm nay rồi.\n\nGrammar extra 2: phân biệt have gone doing something và have been doing something\nTrước hết, ta phân biệt 2 cấu trúc: have gone to somewhere và have been to some where:\n\n- Have gone to somewhere: đã đi đến đâu và chưa về. => nhấn mạnh và hành động đã rời đi. \n\nEg: Peter has gone to Paris. \n\nPeter đã đi Paris rồi (và chưa về).\n\n- Have been to somewhere: đã từng đến đâu (mấy lần) (và đã về) => nhấn mạnh vào số lần đã tới nơi đó. \n\nEg: Peter has been to Paris twice. \n\nPeter đã đến Paris hai lần.  \n\nTương tự như vậy, ta phân biệt 2 cấu trúc: have gone doing something và have been doing something\n\n- Have gone doing something: đã đi làm việc gì đó rồi (và chưa về) => nhấn mạnh và việc đã đi. \n\nEg: Anna has gone swimming since 2pm. \n\nAnna đã đi bơi từ lúc 2 giờ chiều (và chưa về). \n\n- Have been doing something: đã làm việc gì được bao lâu tính đến nay. => nhấn mạnh vào khoảng thời gian \n\nEg: Anna has been swimming since she was 5. \n\nAnna đã (luyện tập môn) bơi suốt từ năm cô ấy 5 tuổi. 	2023-06-29 09:38:15.895	2023-06-29 09:38:15.895
318	208	4	Future 1: Plans, intentions and predictions; present continuous; going to; will	1	https://www.youtube.com/watch?v=EVJyT2uuwSg&ab_channel=STUDY4	0	0		 	2023-06-29 09:39:00.859	2023-06-29 09:39:00.859
319	209	1	Từ vựng IELTS phần 1	3		0	21		 	2023-06-29 09:42:20.841	2023-06-29 09:42:20.841
320	209	2	Từ vựng IELTS phần 2	3		0	24		 	2023-06-29 09:42:34.951	2023-06-29 09:42:34.951
321	210	1	Từ vựng TOEIC phần 1	3		0	22		 	2023-06-29 09:43:02.505	2023-06-29 09:43:02.505
322	210	2	Từ vựng TOEIC phần 2	3		0	25		 	2023-06-29 09:43:19.835	2023-06-29 09:43:19.835
323	211	1	Tiếng Anh thông dụng phần 1	3		0	23		 	2023-06-29 09:43:50.925	2023-06-29 09:43:50.925
324	211	2	Tiếng Anh thông dụng phần 2	3		0	26		 	2023-06-29 09:44:03.55	2023-06-29 09:44:03.55
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
21	1	2023-06-29 09:20:34.538934
\.


--
-- Data for Name: note; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.note (note_id, student_id, lesson_id, note, created_at, updated_at) FROM stdin;
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
21	31	5	2023-06-29 09:20:03.816	2023-06-29 09:20:09.18981
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
\.


--
-- Data for Name: unit; Type: TABLE DATA; Schema: public; Owner: examify_pxac_user
--

COPY public.unit (unit_id, chapter_id, numeric_order, name, total_lesson, created_at, updated_at) FROM stdin;
216	109	1	Ngữ pháp TOEIC Cơ bản	1	2023-06-29 09:58:42.058	2023-06-29 09:58:58.63601
201	101	1	Hướng dẫn làm các dạng câu hỏi trong IELTS Listening	2	2023-06-29 07:49:54.86	2023-06-29 07:52:33.724995
218	111	2	Part 7: Reading Comprehension - Đọc hiểu văn bản	1	2023-06-29 10:01:27.93	2023-06-29 10:02:05.769608
203	102	1	Phương pháp làm các dạng câu hỏi trong IELTS Reading	2	2023-06-29 09:03:31.616	2023-06-29 09:04:59.782984
205	103	1	Phát âm với các đuôi phổ biến	2	2023-06-29 09:15:09.845	2023-06-29 09:17:03.881435
207	104	1	Từ vựng theo chủ đề	2	2023-06-29 09:33:26.694	2023-06-29 09:34:02.034939
220	112	2	Các chiến lược làm bài thi TOEIC	3	2023-06-29 10:04:37.971	2023-06-29 10:07:21.81897
209	105	1	IELTS Related	2	2023-06-29 09:42:00.413	2023-06-29 09:42:34.959079
211	105	3	Tiếng Anh thông dung	2	2023-06-29 09:43:33.347	2023-06-29 09:44:03.552858
213	107	2	Các dạng động từ 	2	2023-06-29 09:49:30.775	2023-06-29 09:50:26.090958
215	108	2	Học cách phát âm	1	2023-06-29 09:52:48.613	2023-06-29 09:53:25.752139
202	101	2	Luyện nghe chính tả từ vựng	2	2023-06-29 07:54:13.167	2023-06-29 08:59:59.987004
217	111	1	Part 3: Conversations - Nghe hiểu đối thoại	1	2023-06-29 10:00:18.152	2023-06-29 10:00:54.886969
204	102	2	Các chiến lược quan trọng khi làm bài thi IELTS Reading	3	2023-06-29 09:07:08.033	2023-06-29 09:10:54.132928
219	112	1	Giới thiệu về TOEIC	1	2023-06-29 10:03:56.162	2023-06-29 10:04:25.652727
206	103	2	Một số chủ đề nổi bật trong Speaking 	1	2023-06-29 09:17:41.833	2023-06-29 09:18:10.976891
208	104	2	Tenses	4	2023-06-29 09:35:44.565	2023-06-29 09:39:01.131933
210	105	2	TOEIC Related	2	2023-06-29 09:42:46.803	2023-06-29 09:43:19.838827
212	107	1	Các thì cơ bản 	1	2023-06-29 09:48:08.096	2023-06-29 09:48:47.287087
214	108	1	Những điều cơ bản trong tiếng Anh	1	2023-06-29 09:51:13.255	2023-06-29 09:52:12.852055
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
21	1	2023-06-03 15:05:02.303472	2023-06-03 15:05:02.303472
22	4	2023-06-29 08:03:53.468124	2023-06-29 08:03:53.468124
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
22	hdatdragon@gmail.com	$2b$10$flERosH3pdw75KuVImDs8e0M8hD3KmYeUOHEGHvz4.BWVQSza7xjC	HOANG DINH ANH	TUAN	\N	\N	https://media.istockphoto.com/id/1223671392/vector/default-profile-picture-avatar-photo-placeholder-vector-illustration.jpg?s=170667a&w=0&k=20&c=m-F9Doa2ecNYEEjeplkFCmZBlc5tm1pl1F7cBCh9ZzM=	data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAX8AAACECAMAAABPuNs7AAAACVBMVEWAgICLi4uUlJSuV9pqAAABI0lEQVR4nO3QMQEAAAjAILV/aGPwjAjMbZybnTjbP9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b+1cxvnHi9hBAfkOyqGAAAAAElFTkSuQmCC	\N	1	0	0	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyIjp7ImlkIjoyMiwiZW1haWwiOiJoZGF0ZHJhZ29uQGdtYWlsLmNvbSIsImZpcnN0TmFtZSI6IkhPQU5HIERJTkggQU5IIiwibGFzdE5hbWUiOiJUVUFOIiwicm9sZSI6IlN0dWRlbnQifSwiaWF0IjoxNjg4MDMzNTY1LCJleHAiOjE3MTk1OTExNjV9.Lh7d2kC6_IrmKIKTFdLonculHuJa-YoUh3tUEpjiats	2023-06-29 08:03:53.468124	2023-06-29 10:16:22.555204
21	hdatdragon2@gmail.com	$2b$10$M1qlGM8CVEqW3BKpCQ1IHeb2PNNcbYZkzjmaNhnfTAMSezsi.SILC	Hoang Dinh Anh 	Tuan	\N	\N	https://media.istockphoto.com/id/1223671392/vector/default-profile-picture-avatar-photo-placeholder-vector-illustration.jpg?s=170667a&w=0&k=20&c=m-F9Doa2ecNYEEjeplkFCmZBlc5tm1pl1F7cBCh9ZzM=	data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAX8AAACECAMAAABPuNs7AAAACVBMVEWAgICLi4uUlJSuV9pqAAABI0lEQVR4nO3QMQEAAAjAILV/aGPwjAjMbZybnTjbP9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b/Vv9W/1b+1cxvnHi9hBAfkOyqGAAAAAElFTkSuQmCC	\N	1	0	0	eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1c2VyIjp7ImlkIjoyMSwiZW1haWwiOiJoZGF0ZHJhZ29uMkBnbWFpbC5jb20iLCJmaXJzdE5hbWUiOiJIb2FuZyBEaW5oIEFuaCAiLCJsYXN0TmFtZSI6IlR1YW4iLCJyb2xlIjoiQWRtaW4ifSwiaWF0IjoxNjg4MDMzNjg3LCJleHAiOjE3MTk1OTEyODd9.QXyZaKr3Wp4HzyQ81COPBMeGsDNtYY_2ad6kJTkHlG4	2023-06-03 15:12:07.045796	2023-06-29 10:14:47.628716
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

SELECT pg_catalog.setval('public.api_product_id_seq', 163, true);


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

SELECT pg_catalog.setval('public.api_variation_id_seq', 544, true);


--
-- Name: api_voucher_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.api_voucher_id_seq', 1, true);


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

SELECT pg_catalog.setval('public.chapter_chapter_id_seq', 112, true);


--
-- Name: choice_choice_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.choice_choice_id_seq', 775, true);


--
-- Name: comment_comment_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.comment_comment_id_seq', 3, true);


--
-- Name: course_course_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.course_course_id_seq', 34, true);


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

SELECT pg_catalog.setval('public.flashcard_fc_id_seq', 261, true);


--
-- Name: flashcard_set_fc_set_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.flashcard_set_fc_set_id_seq', 27, true);


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

SELECT pg_catalog.setval('public.lesson_lesson_id_seq', 336, true);


--
-- Name: note_note_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.note_note_id_seq', 51, true);


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

SELECT pg_catalog.setval('public.unit_unit_id_seq', 220, true);


--
-- Name: users_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: examify_pxac_user
--

SELECT pg_catalog.setval('public.users_user_id_seq', 22, true);


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

