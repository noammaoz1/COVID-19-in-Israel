---------------------------------------
---------- Covid-19 Analysis ----------
---------------------------------------

/* ---------- View tables ---------- */

SELECT *
FROM covid_dataset..covid_deaths
WHERE continent IS NOT NULL
ORDER BY location, date;

SELECT *
FROM covid_dataset..covid_tests
WHERE continent IS NOT NULL
ORDER BY location, date;

SELECT *
FROM covid_dataset..covid_vaccinations
WHERE continent IS NOT NULL
ORDER BY location, date;


/* ---------- Cases & Deaths Analysis ---------- */

-- Infaction cases and deaths by location
SELECT 
    location,
    date,
    population,
    new_cases,
    total_cases,
    new_deaths,
    total_deaths
FROM covid_dataset..covid_deaths
WHERE continent IS NOT NULL;

-- Percentage of covid-19 deaths by country
SELECT 
    continent,
    location,
    date,
    population,
    total_cases,
    total_deaths,
    ROUND((CAST(total_deaths AS FLOAT)/total_cases)*100, 2) AS death_percentage
FROM covid_dataset..covid_deaths
WHERE total_cases > 0
	AND continent IS NOT NULL
ORDER BY location, date;

-- Percentage of covid-19 deaths in Israel
SELECT
    location,
    date,
    population,
    total_cases,
    total_deaths,
    ROUND((CAST(total_deaths AS FLOAT)/total_cases)*100, 2) AS death_percentage
FROM covid_dataset..covid_deaths
WHERE total_cases > 0 AND location LIKE 'Israel'
ORDER BY date;

-- Percentage of population that got covid by country
SELECT 
    location,
    date,
    population,
    total_cases,
    total_deaths,
    ROUND((CAST(total_cases AS FLOAT)/population)*100, 2) AS cases_percentage
FROM covid_dataset..covid_deaths
WHERE total_cases > 0
	AND continent IS NOT NULL
ORDER BY location, date;

-- Percentage of population that got covid in Israel
SELECT 
    location,
    date,
    population,
    total_cases,
    total_deaths,
    ROUND((CAST(total_cases AS FLOAT)/population)*100, 2) AS cases_percentage
FROM covid_dataset..covid_deaths
WHERE total_cases > 0 AND location LIKE 'Israel'
ORDER BY date;

-- The countries with highest infection cases rate
SELECT 
    location,
    population,
    MAX(total_cases) AS all_cases,
    ROUND(MAX(CAST(total_cases AS FLOAT)/population)*100, 2) AS infection_rate
FROM covid_dataset..covid_deaths
WHERE continent IS NOT NULL
GROUP BY location, population
ORDER BY infection_rate DESC;

-- The 4 countries with highest death cases rate & Israel
WITH rates AS (
    SELECT 
        location,
        population,
        MAX(total_cases) AS all_cases,
        MAX(total_deaths) AS all_deaths,
        ROUND(MAX(CAST(total_cases AS FLOAT))/population * 100, 2) AS infection_rate,
        ROUND(MAX(CAST(total_deaths AS FLOAT))/population * 100, 2) AS death_rate
    FROM covid_dataset..covid_deaths
    WHERE continent IS NOT NULL
    GROUP BY location, population
),
top_countries AS (
    SELECT 
        location,
        population,
        infection_rate,
        death_rate,
        DENSE_RANK() OVER (ORDER BY death_rate DESC) AS death_rank
    FROM rates
)
SELECT 
    t.location,
    t.population,
    t.infection_rate,
    t.death_rate
FROM top_countries t
WHERE t.death_rank <= 4
   OR t.location = 'Israel'
ORDER BY death_rate DESC;

-- The countries with highest death cases rate (with rank)
-- Using CTE
WITH death_rate AS (
SELECT 
    continent,
    location,
    population,
    MAX(total_deaths) AS total_deaths,
    ROUND(MAX(CAST(total_deaths AS FLOAT)/population)*100, 2) AS death_rate
FROM covid_dataset..covid_deaths
WHERE continent IS NOT NULL
GROUP BY continent, location, population
)
SELECT
    *,
    DENSE_RANK() OVER (ORDER BY death_rate DESC) AS death_rate_rank
FROM death_rate;


/* ---------- Tests Analysis ---------- */

-- Temp table with main columns
DROP TABLE IF EXISTS #tests_summary;
SELECT 
    continent,
    location, 
    date,
    population,
    new_tests,
    new_tests_per_thousand,
    total_tests,
    total_tests_per_thousand,
    positive_rate
INTO #tests_summary
FROM covid_dataset..covid_tests
WHERE continent IS NOT NULL;

-- Covid tests in relation to the population and the average of positive tests, by country
SELECT
    continent, 
    location,
    population,
    MAX(total_tests) AS total_tests_done,
    ROUND(MAX(total_tests_per_thousand), 2) AS total_test_per_thousand,
    ROUND(AVG(positive_rate)*100, 2) AS avg_positive_perc
FROM #tests_summary
WHERE positive_rate IS NOT NULL
GROUP BY continent, location, population
ORDER BY total_test_per_thousand DESC

-- Number of daily tests and positive rate in Israel
SELECT
    t.location,
    t.date,
    t.population,
    d.new_cases,
    t.new_tests,
    d.new_deaths,
    ROUND(t.positive_rate, 2) AS positive_rate
FROM #tests_summary t
JOIN covid_dataset..covid_deaths d
    ON t.location = d.location
    AND t.date = d.date
WHERE t.location = 'Israel'
ORDER BY t.date;


/* ---------- Vaccination Analysis ---------- */

-- Rolling vaccinations by country & date
SELECT 
    d.continent,
    d.location,
    d.date,
    d.population,
    v.new_vaccinations,
    SUM(CAST(v.new_vaccinations AS bigint)) 
        OVER (PARTITION BY d.location ORDER BY d.location, d.date) AS rolling_vaccinations
FROM covid_dataset..covid_deaths d
JOIN covid_dataset..covid_vaccinations v
	ON d.location  = v.location
	AND d.date = v.date
WHERE d.continent IS NOT NULL
ORDER BY d.location, d.date

-- People vaccinated and the percentage of them, by country
SELECT 
continent,
    location,
    population,
    MAX(people_vaccinated) AS total_people_vac,
    MAX(people_fully_vaccinated) AS total_people_fully_vac,
    ROUND(MAX(CAST(people_vaccinated AS FLOAT) / population * 100) ,2) AS vaccinated_rate,
    ROUND(MAX(CAST(people_fully_vaccinated AS FLOAT) / population * 100) ,2) AS fully_vaccinated_rate
FROM covid_dataset..covid_vaccinations
WHERE continent IS NOT NULL
GROUP BY continent, location, population
ORDER BY vaccinated_rate DESC

-- Vaccinated rate vs. death rate over time, by country
SELECT 
    d.continent,
    d.location,
    d.date,
    d.population,
    d.new_cases,
    d.new_deaths,
    ROUND(CAST(v.people_vaccinated AS FLOAT) / d.population * 100 ,2) AS vaccinated_rate,
    ROUND((CAST(d.total_deaths AS FLOAT)/NULLIF(d.total_cases, 0))*100, 2) AS death_percentage
FROM covid_dataset..covid_deaths d
JOIN covid_dataset..covid_vaccinations v
	ON d.location  = v.location
	AND d.date = v.date
WHERE d.continent IS NOT NULL
ORDER BY d.location, d.date

-- Rolling percentage of vaccinated people & Daily vaccination growth rate in Israel
-- Using CTEs
WITH vac_per_pop AS (
    SELECT 
        continent,
        location,
        date,
        population,
        people_vaccinated,
        people_fully_vaccinated,
        ROUND(CAST(people_vaccinated AS FLOAT) / population * 100 , 2) AS perc_vaccinated,
        ROUND(CAST(people_fully_vaccinated AS FLOAT) / population * 100 , 2) AS perc_fully_vaccinated
    FROM covid_dataset..covid_vaccinations
    WHERE location LIKE 'Israel'
),
growth AS (
SELECT
    date,
    people_vaccinated,
    perc_vaccinated,
    LAG(perc_vaccinated, 1) OVER (ORDER BY date) AS prev_perc_vaccinated
    FROM vac_per_pop
)
SELECT 
    vp.location,
    vp.date,
    vp.population,
    vp.people_vaccinated,
    vp.perc_vaccinated,
    ROUND(g.perc_vaccinated - g.prev_perc_vaccinated, 2) AS daily_growth_percent
FROM vac_per_pop vp
JOIN growth g
    ON vp.date = g.date
WHERE vp.people_vaccinated IS NOT NULL
ORDER BY vp.date;


/* ---------- Global Overview ---------- */

-- The total cases, death cases, tests perc, and people vaccinated percentage, by continent
SELECT 
    d.continent,
    MAX(CAST (d.total_cases AS FLOAT)) AS total_cases,
    MAX(CAST(d.total_deaths AS FLOAT)) AS total_death,
    ROUND(MAX(CAST (d.total_cases AS FLOAT)) / MAX(d.population) * 100, 2) AS infection_rate,
    ROUND(MAX(CAST(d.total_deaths AS FLOAT)) / NULLIF(MAX(CAST(d.total_cases AS FLOAT)), 0) * 100, 2) AS death_rate,
    ROUND(MAX(CAST(v.people_vaccinated AS FLOAT)) / MAX(v.population) * 100 ,2) AS vaccinated_rate,
    ROUND(AVG(t.positive_rate)*100, 2) AS avg_test_positive_rate
FROM covid_dataset..covid_deaths d
JOIN covid_dataset..covid_tests t
    ON d.location = t.location 
    AND d.date = t.date
JOIN covid_dataset..covid_vaccinations v
    ON d.location = v.location
    AND d.date = v.date
WHERE d.continent IS NOT NULL
GROUP BY d.continent
ORDER BY death_rate DESC, infection_rate DESC;

-- The main numbers by country
SELECT 
    d.continent,
    d.location,
    d.population,
    MAX(CAST (d.total_cases AS FLOAT)) AS total_cases,
    MAX(CAST(d.total_deaths AS FLOAT)) AS total_death,
    ROUND(MAX(CAST (d.total_cases AS FLOAT)) / d.population * 100, 2) AS infection_rate,
    ROUND(MAX(CAST(d.total_deaths AS FLOAT)) / NULLIF(MAX(CAST(d.total_cases AS FLOAT)), 0) * 100, 2) AS death_rate,
    ROUND(MAX(CAST(v.people_vaccinated AS FLOAT) / v.population * 100) ,2) AS vaccinated_rate,
    ROUND(AVG(t.positive_rate)*100, 2) AS avg_test_positive_rate
FROM covid_dataset..covid_deaths d
JOIN covid_dataset..covid_tests t
    ON d.location = t.location 
    AND d.date = t.date
JOIN covid_dataset..covid_vaccinations v
    ON d.location = v.location
    AND d.date = v.date
WHERE d.continent IS NOT NULL
GROUP BY d.continent, d.location, d.population
ORDER BY death_rate DESC, infection_rate DESC;

-- The numbers over the world
SELECT 
    SUM(d.population) AS world_population,
    SUM(d.new_cases) AS total_cases,
    SUM(d.new_deaths) AS total_deaths,
    ROUND(SUM(CAST(d.new_cases AS FLOAT))/SUM(d.population)*100,2) AS infection_rate,
    ROUND(SUM(CAST(d.new_deaths AS FLOAT)) / SUM(d.new_cases)*100, 2) AS death_rate,
    ROUND(SUM(CAST(v.people_vaccinated AS FLOAT))/SUM(d.population)*100,2) AS vaccinated_rate
FROM covid_dataset..covid_deaths d
JOIN covid_dataset..covid_vaccinations v
    ON d.location = v.location
    AND d.date = v.date
WHERE d.continent IS NOT NULL;