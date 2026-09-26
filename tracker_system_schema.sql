


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


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."general_newcomer_to_member"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Check if they are currently registered as a newcomer
    IF (SELECT position FROM people WHERE id = NEW.person_id) = 'newcomer' THEN
        -- Check if they have accumulated 3 or more total attendances
        IF (SELECT COUNT(*) FROM general_service_attendance WHERE person_id = NEW.person_id) >= 5 THEN
            -- Update their status automatically
            UPDATE people 
            SET position = 'member' 
            WHERE id = NEW.person_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."general_newcomer_to_member"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."register_member_and_children"("registration_data" "jsonb") RETURNS "jsonb"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
    v_is_adult BOOLEAN;
    v_parent_id INT; -- Change to UUID if your people table uses uuid keys
    v_child_id INT;  -- Change to UUID if your children table uses uuid keys
    v_child JSONB;
    v_relationship TEXT;
BEGIN
    v_is_adult := (registration_data->>'is_adult')::BOOLEAN;

    -- SCENARIO A: Registration is for a Child Alone
    IF v_is_adult = FALSE THEN
        INSERT INTO children (
            first_name, 
            last_name, 
            date_of_birth,
            gender,          -- Example extra field
            emergency_contact    -- Example extra field
            -- 🔴 ADD MORE CHILDREN COLUMNS HERE
        ) 
        VALUES (
            registration_data->'child_details'->>'first_name',
            registration_data->'child_details'->>'last_name',
            (registration_data->'child_details'->>'date_of_birth')::DATE,
            registration_data->'child_details'->>'gender',
            registration_data->'child_details'->>'emergency_contact'
            -- 🔴 MAP THE JSON VALUES FOR THOSE COLUMNS HERE
        );
        
        RETURN jsonb_build_object('status', 'success', 'message', 'Solo child registered successfully.');
    END IF;

    -- SCENARIO B: Registration is for an Adult
    -- 2. Insert Adult into the people table
    INSERT INTO people (
        first_name, 
        last_name, 
        email, 
        phone,
	birthday,
        address,        -- Example extra field
        position,
	department,
	gender  -- Example extra field
        -- 🔴 ADD MORE PEOPLE COLUMNS HERE
    )
    VALUES (
        registration_data->'adult_details'->>'first_name',
        registration_data->'adult_details'->>'last_name',
        registration_data->'adult_details'->>'email',
	registration_data->'adult_details'->>'birthday',
        registration_data->'adult_details'->>'phone',
        registration_data->'adult_details'->>'address',
        registration_data->'adult_details'->>'position'
        -- 🔴 MAP THE JSON VALUES FOR THOSE COLUMNS HERE
    )
    RETURNING id INTO v_parent_id;

    -- 3. Check if there are any children attached
    IF registration_data ? 'children' AND jsonb_array_length(registration_data->'children') > 0 THEN
        FOR v_child IN SELECT * FROM jsonb_array_elements(registration_data->'children') LOOP
            
            -- 3a. Insert each child into the children table
            INSERT INTO children (
                first_name, 
                last_name, 
                date_of_birth,
                gender          -- Example extra field
                  
                -- 🔴 ADD MORE CHILDREN COLUMNS HERE (same as Scenario A)
            )
            VALUES (
                v_child->>'first_name',
                v_child->>'last_name',
                (v_child->>'date_of_birth')::DATE,
                v_child->>'gender'
                
                -- 🔴 MAP THE CHILD LOOP JSON VALUES HERE
            )
            RETURNING id INTO v_child_id;

            v_relationship := v_child->>'relationship';

            -- 3b. Populate the junction table
            INSERT INTO parent_child (parent_id, child_id, relationship)
            VALUES (v_parent_id, v_child_id, v_relationship);

        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'status', 'success', 
        'parent_id', v_parent_id, 
        'message', 'Adult and all listed children registered successfully.'
    );

EXCEPTION WHEN OTHERS THEN
    RETURN jsonb_build_object(
        'status', 'error',
        'message', SQLERRM
    );
END;
$$;


ALTER FUNCTION "public"."register_member_and_children"("registration_data" "jsonb") OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."upgrade_newcomer_to_member"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    -- Check if they are currently registered as a newcomer
    IF (SELECT status FROM people WHERE id = NEW.person_id) = 'newcomer' THEN
        -- Check if they have accumulated 3 or more total attendances
        IF (SELECT COUNT(*) FROM adult_service_attendance WHERE person_id = NEW.person_id) >= 3 THEN
            -- Update their status automatically
            UPDATE people 
            SET status = 'member' 
            WHERE id = NEW.person_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."upgrade_newcomer_to_member"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."child_service_attendance" (
    "id" integer NOT NULL,
    "child_id" integer NOT NULL,
    "service_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "service_name" character varying
);


ALTER TABLE "public"."child_service_attendance" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."child_service_attendance_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."child_service_attendance_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."child_service_attendance_id_seq" OWNED BY "public"."child_service_attendance"."id";



CREATE TABLE IF NOT EXISTS "public"."children" (
    "child_id" integer NOT NULL,
    "date_of_birth" "date",
    "gender" character varying(20) DEFAULT NULL::character varying,
    "emergency_contact" character varying(20) DEFAULT NULL::character varying,
    "first_name" character varying DEFAULT 'Unknown'::character varying NOT NULL,
    "last_name" character varying DEFAULT 'Unknown'::character varying NOT NULL
);


ALTER TABLE "public"."children" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."children_child_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."children_child_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."children_child_id_seq" OWNED BY "public"."children"."child_id";



CREATE OR REPLACE VIEW "public"."children_with_age" WITH ("security_invoker"='true') AS
 SELECT "child_id",
    "first_name",
    "last_name",
    "gender",
    EXTRACT(year FROM "age"("now"(), ("date_of_birth")::timestamp with time zone)) AS "age"
   FROM "public"."children";


ALTER VIEW "public"."children_with_age" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."people" (
    "id" bigint NOT NULL,
    "first_name" character varying(100) NOT NULL,
    "last_name" character varying(100) NOT NULL,
    "phone" character varying(20),
    "email" character varying(255),
    "position" character varying,
    "department" character varying(100) DEFAULT NULL::character varying,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "birthday" "date",
    "address" character varying(255),
    "gender" "text"
);


ALTER TABLE "public"."people" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."dashboard_form_registrations" WITH ("security_invoker"='true') AS
 SELECT ( SELECT "count"(*) AS "count"
           FROM "public"."children") AS "registered_children",
    ( SELECT "count"(*) AS "count"
           FROM "public"."people") AS "registered_adults",
    (( SELECT "count"(*) AS "count"
           FROM "public"."children") + ( SELECT "count"(*) AS "count"
           FROM "public"."people")) AS "total_registered_members"
 LIMIT 10;


ALTER VIEW "public"."dashboard_form_registrations" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."general_service_attendance" (
    "id" integer NOT NULL,
    "person_id" bigint NOT NULL,
    "current_position" character varying(50) NOT NULL,
    "service_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "service_name" character varying(50)
);


ALTER TABLE "public"."general_service_attendance" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."workforce_service_attendance" (
    "id" integer NOT NULL,
    "person_id" bigint,
    "service_date" "date" DEFAULT CURRENT_DATE NOT NULL,
    "service_name" character varying NOT NULL,
    "status" "text"
);


ALTER TABLE "public"."workforce_service_attendance" OWNER TO "postgres";


CREATE OR REPLACE VIEW "public"."dashboard_service_attendance" WITH ("security_invoker"='true') AS
 WITH "child_counts" AS (
         SELECT "child_service_attendance"."service_date",
            "child_service_attendance"."service_name",
            "count"(*) AS "children_total"
           FROM "public"."child_service_attendance"
          GROUP BY "child_service_attendance"."service_date", "child_service_attendance"."service_name"
        ), "adult_counts" AS (
         SELECT "general_service_attendance"."service_date",
            "general_service_attendance"."service_name",
            "count"(*) AS "adult_total"
           FROM "public"."general_service_attendance"
          GROUP BY "general_service_attendance"."service_date", "general_service_attendance"."service_name"
        ), "workforce_counts" AS (
         SELECT "workforce_service_attendance"."service_date",
            "workforce_service_attendance"."service_name",
            "count"(*) AS "workforce_total"
           FROM "public"."workforce_service_attendance"
          GROUP BY "workforce_service_attendance"."service_date", "workforce_service_attendance"."service_name"
        ), "all_services" AS (
         SELECT "child_counts"."service_date",
            "child_counts"."service_name"
           FROM "child_counts"
        UNION
         SELECT "adult_counts"."service_date",
            "adult_counts"."service_name"
           FROM "adult_counts"
        UNION
         SELECT "workforce_counts"."service_date",
            "workforce_counts"."service_name"
           FROM "workforce_counts"
        )
 SELECT "s"."service_date",
    "s"."service_name",
    COALESCE("c"."children_total", (0)::bigint) AS "children_attendance",
    COALESCE("a"."adult_total", (0)::bigint) AS "adult_attendance",
    COALESCE("w"."workforce_total", (0)::bigint) AS "workforce_attendance",
    ((COALESCE("c"."children_total", (0)::bigint) + COALESCE("a"."adult_total", (0)::bigint)) + COALESCE("w"."workforce_total", (0)::bigint)) AS "total_attendance"
   FROM ((("all_services" "s"
     LEFT JOIN "child_counts" "c" ON ((("s"."service_date" = "c"."service_date") AND (("s"."service_name")::"text" = ("c"."service_name")::"text"))))
     LEFT JOIN "adult_counts" "a" ON ((("s"."service_date" = "a"."service_date") AND (("s"."service_name")::"text" = ("a"."service_name")::"text"))))
     LEFT JOIN "workforce_counts" "w" ON ((("s"."service_date" = "w"."service_date") AND (("s"."service_name")::"text" = ("w"."service_name")::"text"))))
  ORDER BY "s"."service_date" DESC, "s"."service_name"
 LIMIT 30;


ALTER VIEW "public"."dashboard_service_attendance" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."general_service_attendance_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."general_service_attendance_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."general_service_attendance_id_seq" OWNED BY "public"."general_service_attendance"."id";



CREATE TABLE IF NOT EXISTS "public"."parent_child" (
    "parent_id" bigint NOT NULL,
    "child_id" integer NOT NULL,
    "relationship_type" character varying(50)
);


ALTER TABLE "public"."parent_child" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."people_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."people_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."people_id_seq" OWNED BY "public"."people"."id";



CREATE OR REPLACE VIEW "public"."upcoming_birthdays" WITH ("security_invoker"='true') AS
 SELECT "people"."id",
    "people"."first_name",
    "people"."last_name",
    'Adult'::"text" AS "category",
    EXTRACT(day FROM "people"."birthday") AS "birth_day",
    EXTRACT(month FROM "people"."birthday") AS "birth_month"
   FROM "public"."people"
  WHERE (("people"."birthday" IS NOT NULL) AND (EXTRACT(month FROM "people"."birthday") = EXTRACT(month FROM CURRENT_DATE)))
UNION ALL
 SELECT "children"."child_id" AS "id",
    "children"."first_name",
    "children"."last_name",
    'Child'::"text" AS "category",
    EXTRACT(day FROM "children"."date_of_birth") AS "birth_day",
    EXTRACT(month FROM "children"."date_of_birth") AS "birth_month"
   FROM "public"."children"
  WHERE (("children"."date_of_birth" IS NOT NULL) AND (EXTRACT(month FROM "children"."date_of_birth") = EXTRACT(month FROM CURRENT_DATE)));


ALTER VIEW "public"."upcoming_birthdays" OWNER TO "postgres";


ALTER TABLE "public"."workforce_service_attendance" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."workforce_service_attendance_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



ALTER TABLE ONLY "public"."child_service_attendance" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."child_service_attendance_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."children" ALTER COLUMN "child_id" SET DEFAULT "nextval"('"public"."children_child_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."general_service_attendance" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."general_service_attendance_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."people" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."people_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."child_service_attendance"
    ADD CONSTRAINT "child_service_attendance_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."children"
    ADD CONSTRAINT "children_pkey" PRIMARY KEY ("child_id");



ALTER TABLE ONLY "public"."general_service_attendance"
    ADD CONSTRAINT "general_service_attendance_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."parent_child"
    ADD CONSTRAINT "parent_child_pkey" PRIMARY KEY ("parent_id", "child_id");



ALTER TABLE ONLY "public"."people"
    ADD CONSTRAINT "people_email_key" UNIQUE ("email");



ALTER TABLE ONLY "public"."people"
    ADD CONSTRAINT "people_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."workforce_service_attendance"
    ADD CONSTRAINT "workforce_service_attendance_pkey" PRIMARY KEY ("id");



CREATE OR REPLACE TRIGGER "general_upgrade_member" AFTER INSERT ON "public"."general_service_attendance" FOR EACH ROW EXECUTE FUNCTION "public"."general_newcomer_to_member"();



ALTER TABLE ONLY "public"."child_service_attendance"
    ADD CONSTRAINT "child_service_attendance_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "public"."children"("child_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."general_service_attendance"
    ADD CONSTRAINT "general_service_attendance_person_id_fkey" FOREIGN KEY ("person_id") REFERENCES "public"."people"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."parent_child"
    ADD CONSTRAINT "parent_child_child_id_fkey" FOREIGN KEY ("child_id") REFERENCES "public"."children"("child_id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."parent_child"
    ADD CONSTRAINT "parent_child_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "public"."people"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."workforce_service_attendance"
    ADD CONSTRAINT "workforce_service_attendance_person_id_fkey" FOREIGN KEY ("person_id") REFERENCES "public"."people"("id") ON DELETE CASCADE;



CREATE POLICY "Allow full access to service_role only" ON "public"."workforce_service_attendance" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Allow service role full access on child_attendance" ON "public"."child_service_attendance" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Allow service role full access on children" ON "public"."children" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Allow service role full access on general_attendance" ON "public"."general_service_attendance" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Allow service role full access on parent_child" ON "public"."parent_child" TO "service_role" USING (true) WITH CHECK (true);



CREATE POLICY "Allow service role full access on people" ON "public"."people" TO "service_role" USING (true) WITH CHECK (true);



ALTER TABLE "public"."child_service_attendance" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."children" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."general_service_attendance" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."parent_child" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."people" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."workforce_service_attendance" ENABLE ROW LEVEL SECURITY;




ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































GRANT ALL ON FUNCTION "public"."general_newcomer_to_member"() TO "anon";
GRANT ALL ON FUNCTION "public"."general_newcomer_to_member"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."general_newcomer_to_member"() TO "service_role";



GRANT ALL ON FUNCTION "public"."register_member_and_children"("registration_data" "jsonb") TO "anon";
GRANT ALL ON FUNCTION "public"."register_member_and_children"("registration_data" "jsonb") TO "authenticated";
GRANT ALL ON FUNCTION "public"."register_member_and_children"("registration_data" "jsonb") TO "service_role";



GRANT ALL ON FUNCTION "public"."upgrade_newcomer_to_member"() TO "anon";
GRANT ALL ON FUNCTION "public"."upgrade_newcomer_to_member"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."upgrade_newcomer_to_member"() TO "service_role";


















GRANT ALL ON TABLE "public"."child_service_attendance" TO "anon";
GRANT ALL ON TABLE "public"."child_service_attendance" TO "authenticated";
GRANT ALL ON TABLE "public"."child_service_attendance" TO "service_role";



GRANT ALL ON SEQUENCE "public"."child_service_attendance_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."child_service_attendance_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."child_service_attendance_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."children" TO "anon";
GRANT ALL ON TABLE "public"."children" TO "authenticated";
GRANT ALL ON TABLE "public"."children" TO "service_role";



GRANT ALL ON SEQUENCE "public"."children_child_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."children_child_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."children_child_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."children_with_age" TO "anon";
GRANT ALL ON TABLE "public"."children_with_age" TO "authenticated";
GRANT ALL ON TABLE "public"."children_with_age" TO "service_role";



GRANT ALL ON TABLE "public"."people" TO "anon";
GRANT ALL ON TABLE "public"."people" TO "authenticated";
GRANT ALL ON TABLE "public"."people" TO "service_role";



GRANT ALL ON TABLE "public"."dashboard_form_registrations" TO "anon";
GRANT ALL ON TABLE "public"."dashboard_form_registrations" TO "authenticated";
GRANT ALL ON TABLE "public"."dashboard_form_registrations" TO "service_role";



GRANT ALL ON TABLE "public"."general_service_attendance" TO "anon";
GRANT ALL ON TABLE "public"."general_service_attendance" TO "authenticated";
GRANT ALL ON TABLE "public"."general_service_attendance" TO "service_role";



GRANT ALL ON TABLE "public"."workforce_service_attendance" TO "anon";
GRANT ALL ON TABLE "public"."workforce_service_attendance" TO "authenticated";
GRANT ALL ON TABLE "public"."workforce_service_attendance" TO "service_role";



GRANT ALL ON TABLE "public"."dashboard_service_attendance" TO "anon";
GRANT ALL ON TABLE "public"."dashboard_service_attendance" TO "authenticated";
GRANT ALL ON TABLE "public"."dashboard_service_attendance" TO "service_role";



GRANT ALL ON SEQUENCE "public"."general_service_attendance_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."general_service_attendance_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."general_service_attendance_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."parent_child" TO "anon";
GRANT ALL ON TABLE "public"."parent_child" TO "authenticated";
GRANT ALL ON TABLE "public"."parent_child" TO "service_role";



GRANT ALL ON SEQUENCE "public"."people_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."people_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."people_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."upcoming_birthdays" TO "anon";
GRANT ALL ON TABLE "public"."upcoming_birthdays" TO "authenticated";
GRANT ALL ON TABLE "public"."upcoming_birthdays" TO "service_role";



GRANT ALL ON SEQUENCE "public"."workforce_service_attendance_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."workforce_service_attendance_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."workforce_service_attendance_id_seq" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";































