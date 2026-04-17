DO $$
BEGIN
    INSERT INTO Dim_Date (date_key, day_number_of_month, month_number_of_year, year_number, day_name, month_name)
    SELECT DISTINCT 
        visit_date,
        EXTRACT(DAY FROM visit_date),
        EXTRACT(MONTH FROM visit_date),
        EXTRACT(YEAR FROM visit_date),
        TO_CHAR(visit_date, 'Day'),
        TO_CHAR(visit_date, 'Month')
    FROM Staging_Gym_visit
    WHERE visit_date IS NOT NULL
    ON CONFLICT (date_key) DO NOTHING;

    UPDATE Staging_Gym_visit s
    SET require_manual_processing = 1
    FROM Dim_Member m
    WHERE s.personal_code = m.personal_code
    AND (
        (s.gym_code = 'Gym_1' AND s.visitor_name != (m.last_name || ' ' || m.first_name))
        OR 
        (s.gym_code = 'Gym_2' AND s.visitor_name != (m.first_name || ' ' || m.last_name))
        OR
        (s.time_in IS NOT NULL AND s.time_out IS NOT NULL AND s.time_out < s.time_in)
    );

    UPDATE Staging_Gym_visit
    SET require_manual_processing = 1
    WHERE gym_code = 'Gym_1' AND time_out IS NULL;

    WITH ConsolidatedVisits AS (
        SELECT 
            visit_date, gym_code, personal_code, time_in, time_out
        FROM Staging_Gym_visit
        WHERE gym_code = 'Gym_1' AND require_manual_processing = 0
        
        UNION ALL

        SELECT 
            visit_date, gym_code, personal_code, 
            MAX(time_in) as time_in, 
            MAX(time_out) as time_out
        FROM Staging_Gym_visit
        WHERE gym_code = 'Gym_2' AND require_manual_processing = 0
        GROUP BY visit_date, gym_code, personal_code
        HAVING MAX(time_out) IS NOT NULL AND MAX(time_in) IS NOT NULL
    ),
    CalculatedData AS (
        SELECT 
            g.gym_id,
            m.member_id,
            cv.visit_date as visit_date_key,
            EXTRACT(EPOCH FROM (cv.time_out - cv.time_in)) / 60 as visit_duration,
            CASE 
                WHEN cv.time_in <= '10:00:00' THEN 'Morning'::day_part_enum
                WHEN cv.time_in <= '17:00:00' THEN 'Day'::day_part_enum
                ELSE 'Evening'::day_part_enum
            END as day_part
        FROM ConsolidatedVisits cv
        JOIN Dim_Gym g ON cv.gym_code = g.gym_code
        JOIN Dim_Member m ON cv.personal_code = m.personal_code
    )
    INSERT INTO Fact_Visit (gym_id, member_id, visit_date_key, visit_duration, day_part)
    SELECT gym_id, member_id, visit_date_key, visit_duration, day_part
    FROM CalculatedData d
    WHERE NOT EXISTS (
        SELECT 1 FROM Fact_Visit f 
        WHERE f.gym_id = d.gym_id 
          AND f.member_id = d.member_id 
          AND f.visit_date_key = d.visit_date_key
          AND f.visit_duration = d.visit_duration
    );

    DELETE FROM Staging_Gym_visit s
    USING Fact_Visit f, Dim_Gym dg, Dim_Member dm
    WHERE s.gym_code = dg.gym_code 
      AND s.personal_code = dm.personal_code
      AND s.visit_date = f.visit_date_key
      AND dg.gym_id = f.gym_id
      AND dm.member_id = f.member_id
      AND s.require_manual_processing = 0;

END $$;

SELECT 'Fact_Visit Count' as info, count(*) FROM Fact_Visit
UNION ALL
SELECT 'Staging Remaining' as info, count(*) FROM Staging_Gym_visit;

