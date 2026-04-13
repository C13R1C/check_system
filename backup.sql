--
-- PostgreSQL database dump
--

\restrict 6poDxA26Rsqc0GnaBcLiIU0MhYlmcXIVjHzQdAtS8WUlxlkJ2lzinYhq8dCdi5k

-- Dumped from database version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.13 (Ubuntu 16.13-0ubuntu0.24.04.1)

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
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: set_updated_at_print3d_jobs(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.set_updated_at_print3d_jobs() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.set_updated_at_print3d_jobs() OWNER TO postgres;

--
-- Name: validate_user_career_level(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_user_career_level() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Si ambos vienen NULL, permite (por ejemplo perfiles incompletos)
  IF NEW.career_id IS NULL OR NEW.academic_level_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM career_level_rules r
    WHERE r.career_id = NEW.career_id
      AND r.academic_level_id = NEW.academic_level_id
  ) THEN
    RAISE EXCEPTION 'Combinación carrera/nivel inválida (career_id=%, academic_level_id=%)',
      NEW.career_id, NEW.academic_level_id;
  END IF;

  RETURN NEW;
END;
$$;


ALTER FUNCTION public.validate_user_career_level() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: academic_levels; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.academic_levels (
    id integer NOT NULL,
    code character varying(20) NOT NULL,
    name character varying(120) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.academic_levels OWNER TO postgres;

--
-- Name: academic_levels_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.academic_levels_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.academic_levels_id_seq OWNER TO postgres;

--
-- Name: academic_levels_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.academic_levels_id_seq OWNED BY public.academic_levels.id;


--
-- Name: alembic_version; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.alembic_version (
    version_num character varying(32) NOT NULL
);


ALTER TABLE public.alembic_version OWNER TO postgres;

--
-- Name: career_level_rules; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.career_level_rules (
    career_id integer NOT NULL,
    academic_level_id integer NOT NULL
);


ALTER TABLE public.career_level_rules OWNER TO postgres;

--
-- Name: careers; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.careers (
    id integer NOT NULL,
    name character varying(160) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.careers OWNER TO postgres;

--
-- Name: careers_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.careers_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.careers_id_seq OWNER TO postgres;

--
-- Name: careers_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.careers_id_seq OWNED BY public.careers.id;


--
-- Name: critical_action_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.critical_action_requests (
    id integer NOT NULL,
    requester_id integer NOT NULL,
    target_user_id integer NOT NULL,
    action_type character varying(50) NOT NULL,
    reason text,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    reviewed_by integer,
    reviewed_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('APPROVED'::character varying)::text, ('REJECTED'::character varying)::text])))
);


ALTER TABLE public.critical_action_requests OWNER TO postgres;

--
-- Name: critical_action_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.critical_action_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.critical_action_requests_id_seq OWNER TO postgres;

--
-- Name: critical_action_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.critical_action_requests_id_seq OWNED BY public.critical_action_requests.id;


--
-- Name: debts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.debts (
    id integer NOT NULL,
    user_id integer NOT NULL,
    material_id integer,
    status character varying(20) NOT NULL,
    reason text,
    amount numeric(10,2),
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    closed_at timestamp without time zone,
    ticket_id integer,
    original_amount numeric(10,2),
    remaining_amount numeric(10,2),
    case_code character varying(36),
    CONSTRAINT ck_debts_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('PAID'::character varying)::text, ('CANCELLED'::character varying)::text])))
);


ALTER TABLE public.debts OWNER TO postgres;

--
-- Name: debts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.debts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.debts_id_seq OWNER TO postgres;

--
-- Name: debts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.debts_id_seq OWNED BY public.debts.id;


--
-- Name: forum_comments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.forum_comments (
    id integer NOT NULL,
    post_id integer NOT NULL,
    content text NOT NULL,
    is_anonymous boolean DEFAULT false NOT NULL,
    is_hidden boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    author_id integer NOT NULL,
    hidden_by integer,
    hidden_at timestamp without time zone
);


ALTER TABLE public.forum_comments OWNER TO postgres;

--
-- Name: forum_comments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.forum_comments_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.forum_comments_id_seq OWNER TO postgres;

--
-- Name: forum_comments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.forum_comments_id_seq OWNED BY public.forum_comments.id;


--
-- Name: forum_posts; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.forum_posts (
    id integer NOT NULL,
    title character varying(200) NOT NULL,
    content text NOT NULL,
    category character varying(50) DEFAULT 'GENERAL'::character varying NOT NULL,
    is_anonymous boolean DEFAULT false NOT NULL,
    is_hidden boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    author_id integer NOT NULL,
    hidden_by integer,
    hidden_at timestamp without time zone
);


ALTER TABLE public.forum_posts OWNER TO postgres;

--
-- Name: forum_posts_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.forum_posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.forum_posts_id_seq OWNER TO postgres;

--
-- Name: forum_posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.forum_posts_id_seq OWNED BY public.forum_posts.id;


--
-- Name: inventory_request_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory_request_items (
    id integer NOT NULL,
    ticket_id integer NOT NULL,
    material_id integer NOT NULL,
    quantity_requested integer NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    quantity_delivered integer NOT NULL,
    quantity_returned integer NOT NULL
);


ALTER TABLE public.inventory_request_items OWNER TO postgres;

--
-- Name: inventory_request_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inventory_request_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inventory_request_items_id_seq OWNER TO postgres;

--
-- Name: inventory_request_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inventory_request_items_id_seq OWNED BY public.inventory_request_items.id;


--
-- Name: inventory_request_tickets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.inventory_request_tickets (
    id integer NOT NULL,
    user_id integer NOT NULL,
    request_date date NOT NULL,
    status character varying(30) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    ready_at timestamp without time zone,
    closed_at timestamp without time zone,
    notes text,
    CONSTRAINT ck_inventory_request_status CHECK (((status)::text = ANY (ARRAY[('OPEN'::character varying)::text, ('READY'::character varying)::text, ('CLOSED'::character varying)::text])))
);


ALTER TABLE public.inventory_request_tickets OWNER TO postgres;

--
-- Name: inventory_request_tickets_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.inventory_request_tickets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.inventory_request_tickets_id_seq OWNER TO postgres;

--
-- Name: inventory_request_tickets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.inventory_request_tickets_id_seq OWNED BY public.inventory_request_tickets.id;


--
-- Name: lab_tickets; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lab_tickets (
    id integer NOT NULL,
    reservation_id integer,
    owner_user_id integer,
    room character varying(120),
    date date,
    status character varying(30) DEFAULT 'OPEN'::character varying,
    opened_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    closed_at timestamp without time zone,
    opened_by_user_id integer,
    closed_by_user_id integer,
    notes text
);


ALTER TABLE public.lab_tickets OWNER TO postgres;

--
-- Name: lab_tickets_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lab_tickets_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.lab_tickets_id_seq OWNER TO postgres;

--
-- Name: lab_tickets_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lab_tickets_id_seq OWNED BY public.lab_tickets.id;


--
-- Name: labs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.labs (
    id integer NOT NULL,
    name character varying(120) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    code character varying(10),
    building character varying(20),
    is_active boolean DEFAULT true
);


ALTER TABLE public.labs OWNER TO postgres;

--
-- Name: labs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.labs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.labs_id_seq OWNER TO postgres;

--
-- Name: labs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.labs_id_seq OWNED BY public.labs.id;


--
-- Name: logbook_events; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.logbook_events (
    id integer NOT NULL,
    user_id integer,
    material_id integer,
    action character varying(80) NOT NULL,
    description text,
    metadata_json text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    module character varying(50),
    entity_label character varying(160)
);


ALTER TABLE public.logbook_events OWNER TO postgres;

--
-- Name: logbook_events_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.logbook_events_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.logbook_events_id_seq OWNER TO postgres;

--
-- Name: logbook_events_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.logbook_events_id_seq OWNED BY public.logbook_events.id;


--
-- Name: lost_found; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.lost_found (
    id integer NOT NULL,
    reported_by_user_id integer,
    material_id integer,
    title character varying(160) NOT NULL,
    description text,
    location character varying(160),
    evidence_ref character varying(255),
    status character varying(20) NOT NULL,
    admin_note text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone
);


ALTER TABLE public.lost_found OWNER TO postgres;

--
-- Name: lost_found_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.lost_found_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.lost_found_id_seq OWNER TO postgres;

--
-- Name: lost_found_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.lost_found_id_seq OWNED BY public.lost_found.id;


--
-- Name: materials; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.materials (
    id integer NOT NULL,
    lab_id integer NOT NULL,
    name text NOT NULL,
    location text,
    status text,
    pieces_text text,
    pieces_qty integer,
    brand text,
    model text,
    code text,
    serial text,
    image_ref text,
    tutorial_url text,
    notes text,
    source_file text,
    source_sheet text,
    source_row integer,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    category character varying(80),
    career_id integer,
    image_url character varying(255)
);


ALTER TABLE public.materials OWNER TO postgres;

--
-- Name: materials_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.materials_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.materials_id_seq OWNER TO postgres;

--
-- Name: materials_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.materials_id_seq OWNED BY public.materials.id;


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.notifications (
    id integer NOT NULL,
    user_id integer NOT NULL,
    title character varying(150) NOT NULL,
    message text NOT NULL,
    link character varying(255),
    is_read boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    related_user_id integer,
    event_code character varying(50),
    is_persistent boolean DEFAULT false
);


ALTER TABLE public.notifications OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.notifications_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.notifications_id_seq OWNER TO postgres;

--
-- Name: notifications_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.notifications_id_seq OWNED BY public.notifications.id;


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.permissions (
    id integer NOT NULL,
    name character varying(100) NOT NULL,
    description character varying(255)
);


ALTER TABLE public.permissions OWNER TO postgres;

--
-- Name: permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.permissions_id_seq OWNER TO postgres;

--
-- Name: permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.permissions_id_seq OWNED BY public.permissions.id;


--
-- Name: print3d_jobs; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.print3d_jobs (
    id integer NOT NULL,
    requester_user_id integer NOT NULL,
    title character varying(255) NOT NULL,
    description text,
    file_ref text NOT NULL,
    original_filename character varying(255) NOT NULL,
    file_size_bytes bigint NOT NULL,
    status character varying(50) DEFAULT 'REQUESTED'::character varying NOT NULL,
    grams_estimated numeric(10,2),
    price_per_gram numeric(10,2),
    total_estimated numeric(10,2),
    admin_note text,
    quoted_by_user_id integer,
    ready_notified_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.print3d_jobs OWNER TO postgres;

--
-- Name: print3d_jobs_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.print3d_jobs_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.print3d_jobs_id_seq OWNER TO postgres;

--
-- Name: print3d_jobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.print3d_jobs_id_seq OWNED BY public.print3d_jobs.id;


--
-- Name: profile_change_requests; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profile_change_requests (
    id integer NOT NULL,
    user_id integer NOT NULL,
    request_type character varying(30) NOT NULL,
    requested_phone character varying(30),
    requested_full_name character varying(150),
    requested_matricula character varying(30),
    requested_career_id integer,
    requested_academic_level_id integer,
    reason text,
    status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    reviewed_by integer,
    reviewed_at timestamp without time zone,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    CONSTRAINT ck_profile_change_requests_request_type CHECK (((request_type)::text = ANY (ARRAY[('PHONE_CHANGE'::character varying)::text, ('PROFILE_CHANGE'::character varying)::text]))),
    CONSTRAINT ck_profile_change_requests_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('APPROVED'::character varying)::text, ('REJECTED'::character varying)::text])))
);


ALTER TABLE public.profile_change_requests OWNER TO postgres;

--
-- Name: profile_change_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.profile_change_requests_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.profile_change_requests_id_seq OWNER TO postgres;

--
-- Name: profile_change_requests_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.profile_change_requests_id_seq OWNED BY public.profile_change_requests.id;


--
-- Name: push_subscriptions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.push_subscriptions (
    id integer NOT NULL,
    user_id integer NOT NULL,
    endpoint text NOT NULL,
    p256dh text NOT NULL,
    auth text NOT NULL,
    user_agent character varying(255),
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.push_subscriptions OWNER TO postgres;

--
-- Name: push_subscriptions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.push_subscriptions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.push_subscriptions_id_seq OWNER TO postgres;

--
-- Name: push_subscriptions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.push_subscriptions_id_seq OWNED BY public.push_subscriptions.id;


--
-- Name: reservation_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reservation_items (
    id integer NOT NULL,
    reservation_id integer NOT NULL,
    material_id integer NOT NULL,
    quantity_requested integer DEFAULT 1 NOT NULL,
    notes text
);


ALTER TABLE public.reservation_items OWNER TO postgres;

--
-- Name: reservation_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.reservation_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.reservation_items_id_seq OWNER TO postgres;

--
-- Name: reservation_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.reservation_items_id_seq OWNED BY public.reservation_items.id;


--
-- Name: reservations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.reservations (
    id integer NOT NULL,
    user_id integer NOT NULL,
    room character varying(80) NOT NULL,
    date date NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    purpose text,
    status character varying(20) NOT NULL,
    admin_note text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone,
    group_name character varying(50) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    teacher_name character varying(120) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    subject character varying(120) DEFAULT 'PENDIENTE'::character varying NOT NULL,
    signed boolean DEFAULT false NOT NULL,
    exit_time time without time zone,
    teacher_comments text,
    subject_id integer,
    signature_ref text,
    CONSTRAINT ck_reservations_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('APPROVED'::character varying)::text, ('REJECTED'::character varying)::text, ('IN_PROGRESS'::character varying)::text, ('COMPLETED'::character varying)::text])))
);


ALTER TABLE public.reservations OWNER TO postgres;

--
-- Name: reservations_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.reservations_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.reservations_id_seq OWNER TO postgres;

--
-- Name: reservations_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.reservations_id_seq OWNED BY public.reservations.id;


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.role_permissions (
    id integer NOT NULL,
    role character varying(20) NOT NULL,
    permission_id integer NOT NULL
);


ALTER TABLE public.role_permissions OWNER TO postgres;

--
-- Name: role_permissions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.role_permissions_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.role_permissions_id_seq OWNER TO postgres;

--
-- Name: role_permissions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.role_permissions_id_seq OWNED BY public.role_permissions.id;


--
-- Name: software; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.software (
    id integer NOT NULL,
    lab_id integer,
    name character varying(160) NOT NULL,
    version character varying(60),
    license_type character varying(60),
    notes text,
    update_requested boolean NOT NULL,
    update_note text,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    updated_at timestamp without time zone
);


ALTER TABLE public.software OWNER TO postgres;

--
-- Name: software_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.software_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.software_id_seq OWNER TO postgres;

--
-- Name: software_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.software_id_seq OWNED BY public.software.id;


--
-- Name: subjects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.subjects (
    id integer NOT NULL,
    career_id integer NOT NULL,
    level character varying(10) NOT NULL,
    quarter integer NOT NULL,
    name character varying(160) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    academic_level_id integer
);


ALTER TABLE public.subjects OWNER TO postgres;

--
-- Name: subjects_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.subjects_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.subjects_id_seq OWNER TO postgres;

--
-- Name: subjects_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.subjects_id_seq OWNED BY public.subjects.id;


--
-- Name: teacher_academic_loads; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.teacher_academic_loads (
    id integer NOT NULL,
    teacher_id integer NOT NULL,
    subject_id integer,
    group_code character varying(20) NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    subject_name character varying(255)
);


ALTER TABLE public.teacher_academic_loads OWNER TO postgres;

--
-- Name: teacher_academic_loads_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.teacher_academic_loads_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.teacher_academic_loads_id_seq OWNER TO postgres;

--
-- Name: teacher_academic_loads_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.teacher_academic_loads_id_seq OWNED BY public.teacher_academic_loads.id;


--
-- Name: ticket_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.ticket_items (
    id integer NOT NULL,
    ticket_id integer,
    material_id integer,
    quantity_requested integer DEFAULT 0,
    quantity_delivered integer DEFAULT 0,
    quantity_returned integer DEFAULT 0,
    status character varying(30) DEFAULT 'REQUESTED'::character varying,
    notes text,
    CONSTRAINT ck_ticket_items_status CHECK (((status)::text = ANY (ARRAY[('PENDING'::character varying)::text, ('DELIVERED'::character varying)::text, ('RETURNED'::character varying)::text])))
);


ALTER TABLE public.ticket_items OWNER TO postgres;

--
-- Name: ticket_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.ticket_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.ticket_items_id_seq OWNER TO postgres;

--
-- Name: ticket_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.ticket_items_id_seq OWNED BY public.ticket_items.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id integer NOT NULL,
    email character varying(120) NOT NULL,
    password_hash character varying(255) NOT NULL,
    role character varying(20) NOT NULL,
    is_verified boolean NOT NULL,
    created_at timestamp without time zone DEFAULT now() NOT NULL,
    verified_at timestamp without time zone,
    profile_completed boolean DEFAULT false NOT NULL,
    full_name character varying(150),
    matricula character varying(30),
    career character varying(120),
    career_year integer,
    phone character varying(30),
    professor_subjects text,
    is_active boolean DEFAULT true NOT NULL,
    is_banned boolean DEFAULT false NOT NULL,
    career_id integer,
    academic_level character varying(10),
    academic_level_id integer,
    profile_data_confirmed boolean DEFAULT false NOT NULL,
    profile_confirmed_at timestamp without time zone,
    current_quarter integer,
    email_verification_code character varying(6),
    email_verification_expires_at timestamp without time zone,
    verification_sent_at timestamp without time zone,
    verify_token_version integer DEFAULT 1,
    email_change_count integer DEFAULT 0,
    email_change_window_started_at timestamp without time zone,
    group_name character varying(80),
    is_root_superadmin boolean DEFAULT false NOT NULL,
    CONSTRAINT check_current_quarter CHECK (((current_quarter >= 1) AND (current_quarter <= 12)))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: academic_levels id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.academic_levels ALTER COLUMN id SET DEFAULT nextval('public.academic_levels_id_seq'::regclass);


--
-- Name: careers id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.careers ALTER COLUMN id SET DEFAULT nextval('public.careers_id_seq'::regclass);


--
-- Name: critical_action_requests id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.critical_action_requests ALTER COLUMN id SET DEFAULT nextval('public.critical_action_requests_id_seq'::regclass);


--
-- Name: debts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.debts ALTER COLUMN id SET DEFAULT nextval('public.debts_id_seq'::regclass);


--
-- Name: forum_comments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forum_comments ALTER COLUMN id SET DEFAULT nextval('public.forum_comments_id_seq'::regclass);


--
-- Name: forum_posts id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forum_posts ALTER COLUMN id SET DEFAULT nextval('public.forum_posts_id_seq'::regclass);


--
-- Name: inventory_request_items id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_request_items ALTER COLUMN id SET DEFAULT nextval('public.inventory_request_items_id_seq'::regclass);


--
-- Name: inventory_request_tickets id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_request_tickets ALTER COLUMN id SET DEFAULT nextval('public.inventory_request_tickets_id_seq'::regclass);


--
-- Name: lab_tickets id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_tickets ALTER COLUMN id SET DEFAULT nextval('public.lab_tickets_id_seq'::regclass);


--
-- Name: labs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.labs ALTER COLUMN id SET DEFAULT nextval('public.labs_id_seq'::regclass);


--
-- Name: logbook_events id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.logbook_events ALTER COLUMN id SET DEFAULT nextval('public.logbook_events_id_seq'::regclass);


--
-- Name: lost_found id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lost_found ALTER COLUMN id SET DEFAULT nextval('public.lost_found_id_seq'::regclass);


--
-- Name: materials id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materials ALTER COLUMN id SET DEFAULT nextval('public.materials_id_seq'::regclass);


--
-- Name: notifications id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications ALTER COLUMN id SET DEFAULT nextval('public.notifications_id_seq'::regclass);


--
-- Name: permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions ALTER COLUMN id SET DEFAULT nextval('public.permissions_id_seq'::regclass);


--
-- Name: print3d_jobs id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.print3d_jobs ALTER COLUMN id SET DEFAULT nextval('public.print3d_jobs_id_seq'::regclass);


--
-- Name: profile_change_requests id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_change_requests ALTER COLUMN id SET DEFAULT nextval('public.profile_change_requests_id_seq'::regclass);


--
-- Name: push_subscriptions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.push_subscriptions ALTER COLUMN id SET DEFAULT nextval('public.push_subscriptions_id_seq'::regclass);


--
-- Name: reservation_items id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservation_items ALTER COLUMN id SET DEFAULT nextval('public.reservation_items_id_seq'::regclass);


--
-- Name: reservations id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservations ALTER COLUMN id SET DEFAULT nextval('public.reservations_id_seq'::regclass);


--
-- Name: role_permissions id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions ALTER COLUMN id SET DEFAULT nextval('public.role_permissions_id_seq'::regclass);


--
-- Name: software id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.software ALTER COLUMN id SET DEFAULT nextval('public.software_id_seq'::regclass);


--
-- Name: subjects id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subjects ALTER COLUMN id SET DEFAULT nextval('public.subjects_id_seq'::regclass);


--
-- Name: teacher_academic_loads id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_academic_loads ALTER COLUMN id SET DEFAULT nextval('public.teacher_academic_loads_id_seq'::regclass);


--
-- Name: ticket_items id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_items ALTER COLUMN id SET DEFAULT nextval('public.ticket_items_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Data for Name: academic_levels; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.academic_levels (id, code, name, is_active, created_at) FROM stdin;
1	TSU	Técnico Superior Universitario	t	2026-04-11 23:22:24.086758
2	ING	Ingeniería	t	2026-04-11 23:22:24.086758
3	LIC	Licenciatura	t	2026-04-11 23:22:24.086758
\.


--
-- Data for Name: alembic_version; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.alembic_version (version_num) FROM stdin;
2a6d4e8f1b3c
1f9b2c4d8e11
9ad4b21c7f01
\.


--
-- Data for Name: career_level_rules; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.career_level_rules (career_id, academic_level_id) FROM stdin;
1	1
2	1
3	1
4	1
5	1
6	1
7	1
1	2
2	2
3	2
4	2
5	2
6	2
7	2
1	3
2	3
3	3
4	3
5	3
6	3
7	3
\.


--
-- Data for Name: careers; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.careers (id, name, created_at) FROM stdin;
1	ING. EN MECATRÓNICA	2026-04-12 22:14:53.410478
2	LIC. EN ADMINISTRACIÓN	2026-04-12 22:14:53.410478
3	ING. EN TECNOLOGÍAS DE LA INFORMACIÓN	2026-04-12 22:14:53.410478
4	ING. EN LOGÍSTICA INTERNACIONAL	2026-04-12 22:14:53.410478
5	ING. INDUSTRIAL	2026-04-12 22:14:53.410478
6	LIC. EN ARQUITECTURA	2026-04-12 22:14:53.410478
7	LIC. EN CONTADURÍA	2026-04-12 22:14:53.410478
\.


--
-- Data for Name: critical_action_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.critical_action_requests (id, requester_id, target_user_id, action_type, reason, status, reviewed_by, reviewed_at, created_at) FROM stdin;
\.


--
-- Data for Name: debts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.debts (id, user_id, material_id, status, reason, amount, created_at, closed_at, ticket_id, original_amount, remaining_amount, case_code) FROM stdin;
\.


--
-- Data for Name: forum_comments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.forum_comments (id, post_id, content, is_anonymous, is_hidden, created_at, updated_at, author_id, hidden_by, hidden_at) FROM stdin;
\.


--
-- Data for Name: forum_posts; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.forum_posts (id, title, content, category, is_anonymous, is_hidden, created_at, updated_at, author_id, hidden_by, hidden_at) FROM stdin;
\.


--
-- Data for Name: inventory_request_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventory_request_items (id, ticket_id, material_id, quantity_requested, created_at, quantity_delivered, quantity_returned) FROM stdin;
\.


--
-- Data for Name: inventory_request_tickets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.inventory_request_tickets (id, user_id, request_date, status, created_at, updated_at, ready_at, closed_at, notes) FROM stdin;
\.


--
-- Data for Name: lab_tickets; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lab_tickets (id, reservation_id, owner_user_id, room, date, status, opened_at, closed_at, opened_by_user_id, closed_by_user_id, notes) FROM stdin;
\.


--
-- Data for Name: labs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.labs (id, name, created_at, code, building, is_active) FROM stdin;
1	B001	2026-04-11 23:22:56.423038	B001	B	t
2	B002	2026-04-11 23:22:56.423038	B002	B	t
3	B003	2026-04-11 23:22:56.423038	B003	B	t
4	B004	2026-04-11 23:22:56.423038	B004	B	t
5	B005	2026-04-11 23:22:56.423038	B005	B	t
6	B006	2026-04-11 23:22:56.423038	B006	B	t
7	B101	2026-04-11 23:22:56.423038	B101	B	t
8	B102	2026-04-11 23:22:56.423038	B102	B	t
9	B103	2026-04-11 23:22:56.423038	B103	B	t
10	B104	2026-04-11 23:22:56.423038	B104	B	t
11	E1	2026-04-11 23:22:56.423038	E001	E	t
12	E2	2026-04-11 23:22:56.423038	E002	E	t
13	E3	2026-04-11 23:22:56.423038	E003	E	t
14	E4	2026-04-11 23:22:56.423038	E004	E	t
15	E5	2026-04-11 23:22:56.423038	E005	E	t
16	E6	2026-04-11 23:22:56.423038	E006	E	t
\.


--
-- Data for Name: logbook_events; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.logbook_events (id, user_id, material_id, action, description, metadata_json, created_at, module, entity_label) FROM stdin;
1	1	1	MATERIAL_CREATED	Material creado: Test 1	{"material_id": 1, "lab_id": 1, "career_id": 7, "status": "Alta - Bueno", "category": "HERRAMIENTA"}	2026-04-11 23:26:23.087171	INVENTORY	Material #1
2	1	1	RA_SCAN	Evento generado desde RA	{}	2026-04-11 23:26:58.151732	RA	Material #1
3	1	1	RA_SCAN	Evento generado desde RA	{}	2026-04-11 23:27:20.500211	RA	Material #1
4	1	1	RA_SCAN	Evento generado desde RA	{}	2026-04-11 23:27:32.531139	RA	Material #1
5	1	1	RA_SCAN	Evento generado desde RA	{}	2026-04-11 23:27:37.660329	RA	Material #1
6	1	\N	PROFILE_UPDATED	Actualización de perfil por el usuario	{"changed_fields": ["phone"], "blocked_fields_attempted": []}	2026-04-12 00:18:31.790386	PROFILE	User #1
7	1	1	RA_SCAN	Evento generado desde RA	{}	2026-04-12 00:23:23.981312	RA	Material #1
8	6	\N	PROFILE_COMPLETED	Perfil completado por el usuario	{"career_id": 3, "academic_level_id": 1, "role": "STUDENT", "profile_identifier": "24310116"}	2026-04-12 23:04:20.351651	PROFILE	User #6
9	5	\N	PROFILE_COMPLETED	Perfil completado por el usuario	{"career_id": 3, "academic_level_id": 1, "role": "STUDENT", "profile_identifier": "24310130"}	2026-04-12 23:09:18.556712	PROFILE	User #5
\.


--
-- Data for Name: lost_found; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.lost_found (id, reported_by_user_id, material_id, title, description, location, evidence_ref, status, admin_note, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: materials; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.materials (id, lab_id, name, location, status, pieces_text, pieces_qty, brand, model, code, serial, image_ref, tutorial_url, notes, source_file, source_sheet, source_row, created_at, updated_at, category, career_id, image_url) FROM stdin;
1	1	Test 1	Estante 1	Alta - Bueno	Kit de 20	2	Steren	2345	B1	142257895531267	uploads\\materials/05576606a8e9495cac222f93f7c394f1.jpg	https://m.youtube.com/watch?v=dQw4w9WgXcQ	Todo bien	\N	\N	\N	2026-04-11 23:26:23.087171	\N	HERRAMIENTA	3	/static/uploads%5Cmaterials/05576606a8e9495cac222f93f7c394f1.jpg
\.


--
-- Data for Name: notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.notifications (id, user_id, title, message, link, is_read, created_at, related_user_id, event_code, is_persistent) FROM stdin;
\.


--
-- Data for Name: permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.permissions (id, name, description) FROM stdin;
1	debts.view_own	View own debts
2	debts.view_all	View all debts
3	debts.create	Create debts
4	debts.close	Close debts
5	reports.view	View reports
6	reports.export	Export reports
7	inventory.view	View inventory
8	lostfound.view	View lost items
9	lostfound.manage	Manage lost items
10	reservations.create	Create reservations
11	reservations.approve	Approve reservations
12	software.view	View software
13	software.request	Request software
14	users.assign_roles	Assign roles
\.


--
-- Data for Name: print3d_jobs; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.print3d_jobs (id, requester_user_id, title, description, file_ref, original_filename, file_size_bytes, status, grams_estimated, price_per_gram, total_estimated, admin_note, quoted_by_user_id, ready_notified_at, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: profile_change_requests; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.profile_change_requests (id, user_id, request_type, requested_phone, requested_full_name, requested_matricula, requested_career_id, requested_academic_level_id, reason, status, reviewed_by, reviewed_at, created_at) FROM stdin;
\.


--
-- Data for Name: push_subscriptions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.push_subscriptions (id, user_id, endpoint, p256dh, auth, user_agent, is_active, created_at, updated_at) FROM stdin;
1	1	https://updates.push.services.mozilla.com/wpush/v2/gAAAAABp2w0cmeO5_Bqp3DofFKu-r2levI1mvOVoubDZ2WYNqKpSlmJGAyedhnpQfKN5ZDBlHTm1ZEHQzqW7JIMEAVyPs4X6YkxjHhb4WzjXzCJQTpfA7nsKBNvPts1tgIQui8jHoIo9mJ6cnkM5x7ICtwlLcUaKTDNrMvT9ZqTMvPpEk_og2nk	BJ8VYdyNVhNMbNethnhwWLJmh4CKh-clA4s1BWiMn51WUnrNFfT-zsIU7ndyxBLvg89GtaMHTOshdikcOZVEzpM	qLxlBcViuK32wwFnLDlzkw	Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:150.0) Gecko/20100101 Firefox/150.0	f	2026-04-11 21:10:20.14996	2026-04-11 21:10:40.357807
2	1	https://updates.push.services.mozilla.com/wpush/v2/gAAAAABp2w0zwcCJk986b5slkIWnUrECljwM0N8JIjvAKfpRct7lOx-JiFeuqLpDsSaWbn_o8iicmrxv6037YneXhJwFFXAJ-wJVpz-AEaIW8T5-Y17bV9TOxP9FeA4yjSjmTzzvNTt0nlo82HHI_HIHyNlTIaOaPIwqggUPxHZ6WCOjcTnpMXs	BMD5_T2QvCw0Mcx-qyz6QWyjuypKVxJV13nE7zihLNlOSZ9nvgmRZU-nSpCwwyZocd7aOBKS-rNoWQ770XHKhuA	zFnqHrTQq6LZZfqKTei-ww	Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:150.0) Gecko/20100101 Firefox/150.0	t	2026-04-11 21:10:42.838777	2026-04-11 21:10:42.838777
3	1	https://fcm.googleapis.com/fcm/send/fZHcZgACt3w:APA91bFf_4QW6wQ6_o66TIUhSyLPBUqUFNrNM53XwQTt1T8_Xcv-aiqKfR8VJ5kqYx4G8s6XKTnlxrF9zMneJR9uaEySVyQM3Qc8VPUtz5mixFU2pWCvBK8A987JwzO89UZo0KFhBb1h	BFAxljA50iTjvbZUEr9U6IsZBLZZEiMmLWXDvzzz_oOPpYWh-oJQ-J9hbs163gbnVNphAXjGYkHqOKoJO_6OpPI	6g-fnKK4vu0XIL0wV4jZtw	Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) SamsungBrowser/29.0 Chrome/136.0.0.0 Mobile Safari/537.36	t	2026-04-11 23:18:27.106929	2026-04-11 23:18:27.106929
\.


--
-- Data for Name: reservation_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reservation_items (id, reservation_id, material_id, quantity_requested, notes) FROM stdin;
\.


--
-- Data for Name: reservations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.reservations (id, user_id, room, date, start_time, end_time, purpose, status, admin_note, created_at, updated_at, group_name, teacher_name, subject, signed, exit_time, teacher_comments, subject_id, signature_ref) FROM stdin;
\.


--
-- Data for Name: role_permissions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.role_permissions (id, role, permission_id) FROM stdin;
1	STUDENT	1
2	STUDENT	7
3	STUDENT	8
4	STUDENT	12
5	TEACHER	1
6	TEACHER	7
7	TEACHER	8
8	TEACHER	10
9	TEACHER	12
10	TEACHER	13
11	STAFF	2
12	STAFF	5
13	STAFF	6
14	STAFF	7
15	STAFF	8
16	STAFF	12
17	ADMIN	1
18	ADMIN	2
19	ADMIN	3
20	ADMIN	4
21	ADMIN	5
22	ADMIN	6
23	ADMIN	7
24	ADMIN	8
25	ADMIN	9
26	ADMIN	10
27	ADMIN	11
28	ADMIN	12
29	ADMIN	13
30	ADMIN	14
31	SUPERADMIN	1
32	SUPERADMIN	2
33	SUPERADMIN	3
34	SUPERADMIN	4
35	SUPERADMIN	5
36	SUPERADMIN	6
37	SUPERADMIN	7
38	SUPERADMIN	8
39	SUPERADMIN	9
40	SUPERADMIN	10
41	SUPERADMIN	11
42	SUPERADMIN	12
43	SUPERADMIN	13
44	SUPERADMIN	14
48	STUDENT	10
\.


--
-- Data for Name: software; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.software (id, lab_id, name, version, license_type, notes, update_requested, update_note, created_at, updated_at) FROM stdin;
\.


--
-- Data for Name: subjects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.subjects (id, career_id, level, quarter, name, is_active, created_at, academic_level_id) FROM stdin;
\.


--
-- Data for Name: teacher_academic_loads; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.teacher_academic_loads (id, teacher_id, subject_id, group_code, created_at, subject_name) FROM stdin;
\.


--
-- Data for Name: ticket_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.ticket_items (id, ticket_id, material_id, quantity_requested, quantity_delivered, quantity_returned, status, notes) FROM stdin;
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, email, password_hash, role, is_verified, created_at, verified_at, profile_completed, full_name, matricula, career, career_year, phone, professor_subjects, is_active, is_banned, career_id, academic_level, academic_level_id, profile_data_confirmed, profile_confirmed_at, current_quarter, email_verification_code, email_verification_expires_at, verification_sent_at, verify_token_version, email_change_count, email_change_window_started_at, group_name, is_root_superadmin) FROM stdin;
1	dev.admin@utpn.edu.mx	scrypt:32768:8:1$lMYETphcoxzpsOKL$7ba44f3ecbb155402caa807a1496de53f9383f25945483194fba8d67180ff47dd32283a9360208f9139a73fce7a876b55a02de1a71da35e7c717f3956af9ccb1	SUPERADMIN	t	2026-04-11 20:10:44.409078	\N	f	Superadmin-root	\N	\N	\N	656-657-9784	\N	t	f	\N	\N	\N	f	\N	\N	\N	\N	\N	1	0	\N	\N	t
6	24310116@utpn.edu.mx	scrypt:32768:8:1$saCzgfI7324xgQRk$2b133b594cc01d64101ab76b54407775de2f00f9c9028dd1a7e370eb2c4d66fb848769ad7616496651d771b1b054c6b02494dcd51675fb4696d1735e5af2233e	STUDENT	t	2026-04-12 21:52:38.983384	2026-04-12 21:53:23.190326	t	Santiago Gonzalez Coba	24310116	ING. EN TECNOLOGÍAS DE LA INFORMACIÓN	\N	656-657-9784	\N	t	f	3	TSU	1	t	2026-04-12 23:04:20.315863	\N	\N	\N	\N	0	0	\N	TRM51	f
5	24310130@utpn.edu.mx	scrypt:32768:8:1$RGxIZB6SN48QdIMU$8bbae64ebf33f227f9c1f40ebc100032651ed8d6c817770dc6a067c2e00d8406b4e46f36722171c95eea0b2c4143b2cb4a6b572f6e90f9543483f737d47bbe14	STUDENT	t	2026-04-12 21:48:29.046492	2026-04-12 21:48:53.714398	t	Javier Alexis Herrera Castro	24310130	ING. EN TECNOLOGÍAS DE LA INFORMACIÓN	\N	6564590719	\N	t	f	3	TSU	1	t	2026-04-12 23:09:18.519229	\N	\N	\N	\N	0	0	\N	TRM51	f
\.


--
-- Name: academic_levels_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.academic_levels_id_seq', 3, true);


--
-- Name: careers_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.careers_id_seq', 1, false);


--
-- Name: critical_action_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.critical_action_requests_id_seq', 1, false);


--
-- Name: debts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.debts_id_seq', 1, false);


--
-- Name: forum_comments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.forum_comments_id_seq', 1, false);


--
-- Name: forum_posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.forum_posts_id_seq', 1, false);


--
-- Name: inventory_request_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.inventory_request_items_id_seq', 1, false);


--
-- Name: inventory_request_tickets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.inventory_request_tickets_id_seq', 1, false);


--
-- Name: lab_tickets_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.lab_tickets_id_seq', 1, false);


--
-- Name: labs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.labs_id_seq', 16, true);


--
-- Name: logbook_events_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.logbook_events_id_seq', 9, true);


--
-- Name: lost_found_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.lost_found_id_seq', 1, false);


--
-- Name: materials_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.materials_id_seq', 1, true);


--
-- Name: notifications_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.notifications_id_seq', 1, false);


--
-- Name: permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.permissions_id_seq', 14, true);


--
-- Name: print3d_jobs_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.print3d_jobs_id_seq', 1, false);


--
-- Name: profile_change_requests_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.profile_change_requests_id_seq', 1, false);


--
-- Name: push_subscriptions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.push_subscriptions_id_seq', 3, true);


--
-- Name: reservation_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.reservation_items_id_seq', 1, false);


--
-- Name: reservations_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.reservations_id_seq', 1, false);


--
-- Name: role_permissions_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.role_permissions_id_seq', 48, true);


--
-- Name: software_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.software_id_seq', 1, false);


--
-- Name: subjects_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.subjects_id_seq', 1, false);


--
-- Name: teacher_academic_loads_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.teacher_academic_loads_id_seq', 1, false);


--
-- Name: ticket_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.ticket_items_id_seq', 1, false);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 6, true);


--
-- Name: academic_levels academic_levels_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.academic_levels
    ADD CONSTRAINT academic_levels_pkey PRIMARY KEY (id);


--
-- Name: alembic_version alembic_version_pkc; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.alembic_version
    ADD CONSTRAINT alembic_version_pkc PRIMARY KEY (version_num);


--
-- Name: career_level_rules career_level_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.career_level_rules
    ADD CONSTRAINT career_level_rules_pkey PRIMARY KEY (career_id, academic_level_id);


--
-- Name: careers careers_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.careers
    ADD CONSTRAINT careers_name_key UNIQUE (name);


--
-- Name: careers careers_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.careers
    ADD CONSTRAINT careers_pkey PRIMARY KEY (id);


--
-- Name: critical_action_requests critical_action_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.critical_action_requests
    ADD CONSTRAINT critical_action_requests_pkey PRIMARY KEY (id);


--
-- Name: debts debts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.debts
    ADD CONSTRAINT debts_pkey PRIMARY KEY (id);


--
-- Name: forum_comments forum_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forum_comments
    ADD CONSTRAINT forum_comments_pkey PRIMARY KEY (id);


--
-- Name: forum_posts forum_posts_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT forum_posts_pkey PRIMARY KEY (id);


--
-- Name: inventory_request_items inventory_request_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_request_items
    ADD CONSTRAINT inventory_request_items_pkey PRIMARY KEY (id);


--
-- Name: inventory_request_tickets inventory_request_tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_request_tickets
    ADD CONSTRAINT inventory_request_tickets_pkey PRIMARY KEY (id);


--
-- Name: lab_tickets lab_tickets_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_tickets
    ADD CONSTRAINT lab_tickets_pkey PRIMARY KEY (id);


--
-- Name: labs labs_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.labs
    ADD CONSTRAINT labs_name_key UNIQUE (name);


--
-- Name: labs labs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.labs
    ADD CONSTRAINT labs_pkey PRIMARY KEY (id);


--
-- Name: logbook_events logbook_events_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.logbook_events
    ADD CONSTRAINT logbook_events_pkey PRIMARY KEY (id);


--
-- Name: lost_found lost_found_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lost_found
    ADD CONSTRAINT lost_found_pkey PRIMARY KEY (id);


--
-- Name: materials materials_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materials
    ADD CONSTRAINT materials_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: permissions permissions_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_name_key UNIQUE (name);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: print3d_jobs print3d_jobs_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.print3d_jobs
    ADD CONSTRAINT print3d_jobs_pkey PRIMARY KEY (id);


--
-- Name: profile_change_requests profile_change_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_change_requests
    ADD CONSTRAINT profile_change_requests_pkey PRIMARY KEY (id);


--
-- Name: push_subscriptions push_subscriptions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_pkey PRIMARY KEY (id);


--
-- Name: reservation_items reservation_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservation_items
    ADD CONSTRAINT reservation_items_pkey PRIMARY KEY (id);


--
-- Name: reservations reservations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (id);


--
-- Name: software software_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.software
    ADD CONSTRAINT software_pkey PRIMARY KEY (id);


--
-- Name: subjects subjects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_pkey PRIMARY KEY (id);


--
-- Name: teacher_academic_loads teacher_academic_loads_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_academic_loads
    ADD CONSTRAINT teacher_academic_loads_pkey PRIMARY KEY (id);


--
-- Name: ticket_items ticket_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_items
    ADD CONSTRAINT ticket_items_pkey PRIMARY KEY (id);


--
-- Name: academic_levels uq_academic_levels_code; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.academic_levels
    ADD CONSTRAINT uq_academic_levels_code UNIQUE (code);


--
-- Name: academic_levels uq_academic_levels_name; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.academic_levels
    ADD CONSTRAINT uq_academic_levels_name UNIQUE (name);


--
-- Name: inventory_request_items uq_inventory_request_item_ticket_material; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_request_items
    ADD CONSTRAINT uq_inventory_request_item_ticket_material UNIQUE (ticket_id, material_id);


--
-- Name: push_subscriptions uq_push_subscription_user_endpoint; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT uq_push_subscription_user_endpoint UNIQUE (user_id, endpoint);


--
-- Name: role_permissions uq_role_permission; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT uq_role_permission UNIQUE (role, permission_id);


--
-- Name: subjects uq_subject_catalog; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT uq_subject_catalog UNIQUE (career_id, level, quarter, name);


--
-- Name: teacher_academic_loads uq_teacher_subject_group; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_academic_loads
    ADD CONSTRAINT uq_teacher_subject_group UNIQUE (teacher_id, subject_id, group_code);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: idx_debts_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_debts_user ON public.debts USING btree (user_id);


--
-- Name: idx_lab_tickets_reservation_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_lab_tickets_reservation_id ON public.lab_tickets USING btree (reservation_id);


--
-- Name: idx_notifications_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_notifications_user ON public.notifications USING btree (user_id);


--
-- Name: idx_reservation_items_reservation_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reservation_items_reservation_id ON public.reservation_items USING btree (reservation_id);


--
-- Name: idx_reservations_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reservations_date ON public.reservations USING btree (date);


--
-- Name: idx_reservations_user; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_reservations_user ON public.reservations USING btree (user_id);


--
-- Name: idx_ticket_items_material; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ticket_items_material ON public.ticket_items USING btree (material_id);


--
-- Name: idx_ticket_items_ticket_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_ticket_items_ticket_id ON public.ticket_items USING btree (ticket_id);


--
-- Name: ix_academic_levels_is_active; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_academic_levels_is_active ON public.academic_levels USING btree (is_active);


--
-- Name: ix_debts_case_code; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_debts_case_code ON public.debts USING btree (case_code);


--
-- Name: ix_debts_ticket_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_debts_ticket_id ON public.debts USING btree (ticket_id);


--
-- Name: ix_forum_comments_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_forum_comments_created_at ON public.forum_comments USING btree (created_at DESC);


--
-- Name: ix_forum_comments_hidden; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_forum_comments_hidden ON public.forum_comments USING btree (is_hidden);


--
-- Name: ix_forum_comments_post_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_forum_comments_post_id ON public.forum_comments USING btree (post_id);


--
-- Name: ix_forum_posts_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_forum_posts_category ON public.forum_posts USING btree (category);


--
-- Name: ix_forum_posts_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_forum_posts_created_at ON public.forum_posts USING btree (created_at DESC);


--
-- Name: ix_forum_posts_hidden; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_forum_posts_hidden ON public.forum_posts USING btree (is_hidden);


--
-- Name: ix_inventory_request_tickets_request_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_inventory_request_tickets_request_date ON public.inventory_request_tickets USING btree (request_date);


--
-- Name: ix_inventory_request_tickets_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_inventory_request_tickets_status ON public.inventory_request_tickets USING btree (status);


--
-- Name: ix_inventory_request_tickets_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_inventory_request_tickets_user_id ON public.inventory_request_tickets USING btree (user_id);


--
-- Name: ix_logbook_events_module; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_logbook_events_module ON public.logbook_events USING btree (module);


--
-- Name: ix_materials_category; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_materials_category ON public.materials USING btree (category);


--
-- Name: ix_print3d_jobs_created_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_print3d_jobs_created_at ON public.print3d_jobs USING btree (created_at);


--
-- Name: ix_print3d_jobs_requester_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_print3d_jobs_requester_user_id ON public.print3d_jobs USING btree (requester_user_id);


--
-- Name: ix_print3d_jobs_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_print3d_jobs_status ON public.print3d_jobs USING btree (status);


--
-- Name: ix_profile_change_requests_request_type; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_profile_change_requests_request_type ON public.profile_change_requests USING btree (request_type);


--
-- Name: ix_profile_change_requests_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_profile_change_requests_status ON public.profile_change_requests USING btree (status);


--
-- Name: ix_profile_change_requests_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_profile_change_requests_user_id ON public.profile_change_requests USING btree (user_id);


--
-- Name: ix_push_subscriptions_user_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_push_subscriptions_user_id ON public.push_subscriptions USING btree (user_id);


--
-- Name: ix_reservations_subject_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_reservations_subject_id ON public.reservations USING btree (subject_id);


--
-- Name: ix_subjects_academic_level_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_subjects_academic_level_id ON public.subjects USING btree (academic_level_id);


--
-- Name: ix_subjects_career_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_subjects_career_id ON public.subjects USING btree (career_id);


--
-- Name: ix_subjects_level; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_subjects_level ON public.subjects USING btree (level);


--
-- Name: ix_teacher_academic_loads_subject_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_teacher_academic_loads_subject_id ON public.teacher_academic_loads USING btree (subject_id);


--
-- Name: ix_teacher_academic_loads_teacher_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_teacher_academic_loads_teacher_id ON public.teacher_academic_loads USING btree (teacher_id);


--
-- Name: ix_users_academic_level_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX ix_users_academic_level_id ON public.users USING btree (academic_level_id);


--
-- Name: print3d_jobs trg_set_updated_at_print3d_jobs; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_set_updated_at_print3d_jobs BEFORE UPDATE ON public.print3d_jobs FOR EACH ROW EXECUTE FUNCTION public.set_updated_at_print3d_jobs();


--
-- Name: users trg_validate_user_career_level; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER trg_validate_user_career_level BEFORE INSERT OR UPDATE OF career_id, academic_level_id ON public.users FOR EACH ROW EXECUTE FUNCTION public.validate_user_career_level();


--
-- Name: career_level_rules career_level_rules_academic_level_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.career_level_rules
    ADD CONSTRAINT career_level_rules_academic_level_id_fkey FOREIGN KEY (academic_level_id) REFERENCES public.academic_levels(id) ON DELETE CASCADE;


--
-- Name: career_level_rules career_level_rules_career_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.career_level_rules
    ADD CONSTRAINT career_level_rules_career_id_fkey FOREIGN KEY (career_id) REFERENCES public.careers(id) ON DELETE CASCADE;


--
-- Name: debts debts_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.debts
    ADD CONSTRAINT debts_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materials(id);


--
-- Name: debts debts_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.debts
    ADD CONSTRAINT debts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: debts fk_debts_ticket_id_lab_tickets; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.debts
    ADD CONSTRAINT fk_debts_ticket_id_lab_tickets FOREIGN KEY (ticket_id) REFERENCES public.lab_tickets(id);


--
-- Name: forum_comments fk_forum_comments_author; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forum_comments
    ADD CONSTRAINT fk_forum_comments_author FOREIGN KEY (author_id) REFERENCES public.users(id);


--
-- Name: forum_comments fk_forum_comments_hidden_by; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forum_comments
    ADD CONSTRAINT fk_forum_comments_hidden_by FOREIGN KEY (hidden_by) REFERENCES public.users(id);


--
-- Name: forum_comments fk_forum_comments_post; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forum_comments
    ADD CONSTRAINT fk_forum_comments_post FOREIGN KEY (post_id) REFERENCES public.forum_posts(id) ON DELETE CASCADE;


--
-- Name: forum_posts fk_forum_posts_author; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT fk_forum_posts_author FOREIGN KEY (author_id) REFERENCES public.users(id);


--
-- Name: forum_posts fk_forum_posts_hidden_by; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT fk_forum_posts_hidden_by FOREIGN KEY (hidden_by) REFERENCES public.users(id);


--
-- Name: forum_posts fk_hidden_by_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.forum_posts
    ADD CONSTRAINT fk_hidden_by_user FOREIGN KEY (hidden_by) REFERENCES public.users(id);


--
-- Name: materials fk_materials_career; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materials
    ADD CONSTRAINT fk_materials_career FOREIGN KEY (career_id) REFERENCES public.careers(id);


--
-- Name: notifications fk_notifications_related_user; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_notifications_related_user FOREIGN KEY (related_user_id) REFERENCES public.users(id);


--
-- Name: notifications fk_notifications_related_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT fk_notifications_related_user_id FOREIGN KEY (related_user_id) REFERENCES public.users(id);


--
-- Name: print3d_jobs fk_print3d_jobs_quoted_by; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.print3d_jobs
    ADD CONSTRAINT fk_print3d_jobs_quoted_by FOREIGN KEY (quoted_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: print3d_jobs fk_print3d_jobs_requester; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.print3d_jobs
    ADD CONSTRAINT fk_print3d_jobs_requester FOREIGN KEY (requester_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: profile_change_requests fk_profile_change_requests_requested_academic_level_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_change_requests
    ADD CONSTRAINT fk_profile_change_requests_requested_academic_level_id FOREIGN KEY (requested_academic_level_id) REFERENCES public.academic_levels(id);


--
-- Name: profile_change_requests fk_profile_change_requests_requested_career_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_change_requests
    ADD CONSTRAINT fk_profile_change_requests_requested_career_id FOREIGN KEY (requested_career_id) REFERENCES public.careers(id);


--
-- Name: profile_change_requests fk_profile_change_requests_reviewed_by; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_change_requests
    ADD CONSTRAINT fk_profile_change_requests_reviewed_by FOREIGN KEY (reviewed_by) REFERENCES public.users(id);


--
-- Name: profile_change_requests fk_profile_change_requests_user_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profile_change_requests
    ADD CONSTRAINT fk_profile_change_requests_user_id FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: critical_action_requests fk_requester; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.critical_action_requests
    ADD CONSTRAINT fk_requester FOREIGN KEY (requester_id) REFERENCES public.users(id);


--
-- Name: reservations fk_reservations_subject_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT fk_reservations_subject_id FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: critical_action_requests fk_reviewer; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.critical_action_requests
    ADD CONSTRAINT fk_reviewer FOREIGN KEY (reviewed_by) REFERENCES public.users(id);


--
-- Name: subjects fk_subjects_academic_level_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT fk_subjects_academic_level_id FOREIGN KEY (academic_level_id) REFERENCES public.academic_levels(id);


--
-- Name: critical_action_requests fk_target; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.critical_action_requests
    ADD CONSTRAINT fk_target FOREIGN KEY (target_user_id) REFERENCES public.users(id);


--
-- Name: users fk_users_academic_level_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_academic_level_id FOREIGN KEY (academic_level_id) REFERENCES public.academic_levels(id);


--
-- Name: users fk_users_career_id; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT fk_users_career_id FOREIGN KEY (career_id) REFERENCES public.careers(id);


--
-- Name: inventory_request_items inventory_request_items_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_request_items
    ADD CONSTRAINT inventory_request_items_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materials(id);


--
-- Name: inventory_request_items inventory_request_items_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_request_items
    ADD CONSTRAINT inventory_request_items_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.inventory_request_tickets(id);


--
-- Name: inventory_request_tickets inventory_request_tickets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.inventory_request_tickets
    ADD CONSTRAINT inventory_request_tickets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: lab_tickets lab_tickets_closed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_tickets
    ADD CONSTRAINT lab_tickets_closed_by_user_id_fkey FOREIGN KEY (closed_by_user_id) REFERENCES public.users(id);


--
-- Name: lab_tickets lab_tickets_opened_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_tickets
    ADD CONSTRAINT lab_tickets_opened_by_user_id_fkey FOREIGN KEY (opened_by_user_id) REFERENCES public.users(id);


--
-- Name: lab_tickets lab_tickets_owner_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_tickets
    ADD CONSTRAINT lab_tickets_owner_user_id_fkey FOREIGN KEY (owner_user_id) REFERENCES public.users(id);


--
-- Name: lab_tickets lab_tickets_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lab_tickets
    ADD CONSTRAINT lab_tickets_reservation_id_fkey FOREIGN KEY (reservation_id) REFERENCES public.reservations(id);


--
-- Name: logbook_events logbook_events_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.logbook_events
    ADD CONSTRAINT logbook_events_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materials(id);


--
-- Name: logbook_events logbook_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.logbook_events
    ADD CONSTRAINT logbook_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: lost_found lost_found_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lost_found
    ADD CONSTRAINT lost_found_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materials(id);


--
-- Name: lost_found lost_found_reported_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.lost_found
    ADD CONSTRAINT lost_found_reported_by_user_id_fkey FOREIGN KEY (reported_by_user_id) REFERENCES public.users(id);


--
-- Name: materials materials_lab_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.materials
    ADD CONSTRAINT materials_lab_id_fkey FOREIGN KEY (lab_id) REFERENCES public.labs(id);


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: push_subscriptions push_subscriptions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.push_subscriptions
    ADD CONSTRAINT push_subscriptions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reservation_items reservation_items_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservation_items
    ADD CONSTRAINT reservation_items_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materials(id);


--
-- Name: reservation_items reservation_items_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservation_items
    ADD CONSTRAINT reservation_items_reservation_id_fkey FOREIGN KEY (reservation_id) REFERENCES public.reservations(id) ON DELETE CASCADE;


--
-- Name: reservations reservations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.reservations
    ADD CONSTRAINT reservations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: software software_lab_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.software
    ADD CONSTRAINT software_lab_id_fkey FOREIGN KEY (lab_id) REFERENCES public.labs(id);


--
-- Name: subjects subjects_career_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.subjects
    ADD CONSTRAINT subjects_career_id_fkey FOREIGN KEY (career_id) REFERENCES public.careers(id);


--
-- Name: teacher_academic_loads teacher_academic_loads_subject_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_academic_loads
    ADD CONSTRAINT teacher_academic_loads_subject_id_fkey FOREIGN KEY (subject_id) REFERENCES public.subjects(id);


--
-- Name: teacher_academic_loads teacher_academic_loads_teacher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.teacher_academic_loads
    ADD CONSTRAINT teacher_academic_loads_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.users(id);


--
-- Name: ticket_items ticket_items_material_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_items
    ADD CONSTRAINT ticket_items_material_id_fkey FOREIGN KEY (material_id) REFERENCES public.materials(id);


--
-- Name: ticket_items ticket_items_ticket_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.ticket_items
    ADD CONSTRAINT ticket_items_ticket_id_fkey FOREIGN KEY (ticket_id) REFERENCES public.lab_tickets(id);


--
-- PostgreSQL database dump complete
--

\unrestrict 6poDxA26Rsqc0GnaBcLiIU0MhYlmcXIVjHzQdAtS8WUlxlkJ2lzinYhq8dCdi5k

