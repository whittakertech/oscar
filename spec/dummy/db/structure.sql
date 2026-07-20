SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: crates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.crates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: gadgets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gadgets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: gizmos; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.gizmos (
    id bigint NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: gizmos_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.gizmos_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: gizmos_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.gizmos_id_seq OWNED BY public.gizmos.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.orders (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    package_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: oscar_statuses; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.oscar_statuses (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    resource_type character varying,
    resource_id character varying,
    resource_role character varying,
    is_prime boolean DEFAULT false NOT NULL,
    superseded_by_id uuid,
    state character varying NOT NULL,
    verb character varying NOT NULL,
    transitioned_at timestamp(6) without time zone NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: packages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.packages (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: posts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.posts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    title character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: widgets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.widgets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    crate_id uuid,
    flag_a boolean DEFAULT false NOT NULL,
    flag_b boolean DEFAULT false NOT NULL
);


--
-- Name: gizmos id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gizmos ALTER COLUMN id SET DEFAULT nextval('public.gizmos_id_seq'::regclass);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: crates crates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.crates
    ADD CONSTRAINT crates_pkey PRIMARY KEY (id);


--
-- Name: gadgets gadgets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gadgets
    ADD CONSTRAINT gadgets_pkey PRIMARY KEY (id);


--
-- Name: gizmos gizmos_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.gizmos
    ADD CONSTRAINT gizmos_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: oscar_statuses oscar_statuses_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.oscar_statuses
    ADD CONSTRAINT oscar_statuses_pkey PRIMARY KEY (id);


--
-- Name: packages packages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.packages
    ADD CONSTRAINT packages_pkey PRIMARY KEY (id);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: widgets widgets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.widgets
    ADD CONSTRAINT widgets_pkey PRIMARY KEY (id);


--
-- Name: index_orders_on_package_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_orders_on_package_id ON public.orders USING btree (package_id);


--
-- Name: index_oscar_statuses_on_resource; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oscar_statuses_on_resource ON public.oscar_statuses USING btree (resource_type, resource_id);


--
-- Name: index_oscar_statuses_on_resource_type_and_resource_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_oscar_statuses_on_resource_type_and_resource_id ON public.oscar_statuses USING btree (resource_type, resource_id);


--
-- Name: index_oscar_statuses_prime; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_oscar_statuses_prime ON public.oscar_statuses USING btree (resource_type, resource_id, resource_role) WHERE is_prime;


--
-- Name: index_packages_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_packages_on_name ON public.packages USING btree (name);


--
-- Name: index_widgets_on_crate_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_widgets_on_crate_id ON public.widgets USING btree (crate_id);


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20260713220800'),
('20260713220700'),
('20260713220600'),
('20260713220500'),
('20260713220400'),
('20260713220300'),
('20260713220200'),
('20260713220100'),
('20260713220000');

