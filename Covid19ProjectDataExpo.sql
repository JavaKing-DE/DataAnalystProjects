/*
==================================================================================
 COVID-19 DATA EXPLORATION PROJECT
==================================================================================

📘 Overview:
This SQL project explores COVID-19 data using two main datasets:
  1. CovidDeaths
  2. CovidVaccinations

The analysis includes:
- Inspecting and preparing data
- Calculating key metrics (death %, infection %, vaccination %)
- Aggregating global and regional statistics
- Joining datasets
- Using window functions, CTEs, and temp tables
- Creating a view for visualizations
- Alo some cleaning and adding data (adding columns, mapping continents)

📂 Database: ProjectData1
📊 Tables: CovidDeaths, CovidVaccinations

👨‍💻 Author: Kingkar Bhowmick
📅 Created: [September,2025]
📍 Tools: Microsoft SQL Server (SSMS)

==================================================================================
*/

------------------------------------------------------------
--  VIEW RAW DATA
------------------------------------------------------------

--  View all records from CovidDeaths table
-- "ProjectData1" is the database, "CovidDeaths" is the table.
-- Ordered by Country and Date for readability
SELECT * 
FROM ProjectData1..CovidDeaths
ORDER BY 2,3;

-- View all records from CovidVaccinations table
-- Used later for joins and vaccination analysis
SELECT * 
FROM ProjectData1..CovidVaccinations
ORDER BY 2;


------------------------------------------------------------
--  SELECT RELEVANT DATA FOR ANALYSIS
------------------------------------------------------------

-- Selecting key columns to focus on: total cases, deaths, and population
SELECT Country, date, total_cases, new_cases, total_deaths, population
FROM ProjectData1.dbo.CovidDeaths
WHERE Country IN ('Bangladesh','Oman')
ORDER BY 1,2;


------------------------------------------------------------
--  TOTAL CASES VS TOTAL DEATHS
-- Calculates death percentage to measure fatality rate
------------------------------------------------------------

SELECT Country, date, total_cases, total_deaths, 
       (total_deaths/total_cases)*100 AS DeathPercentage
FROM ProjectData1.dbo.CovidDeaths
WHERE Country IN ('Bangladesh','Oman')
ORDER BY 1,2;


------------------------------------------------------------
--  TOTAL CASES VS POPULATION
-- Shows the percentage of population infected
------------------------------------------------------------

SELECT Country, date, population, total_cases, 
       (total_cases/population)*100 AS CasePercentage
FROM ProjectData1.dbo.CovidDeaths
WHERE Country IN ('Bangladesh','Oman')
ORDER BY 1,2;


------------------------------------------------------------
--  COUNTRIES WITH HIGHEST INFECTION RATE
-- Compares infection count and percentage of population infected
------------------------------------------------------------

SELECT Country, population, 
       MAX(total_cases) AS HighestInfectionCount, 
       MAX((total_cases/population))*100 AS InfectedPopulationPercentage
FROM ProjectData1.dbo.CovidDeaths
GROUP BY Country, population
HAVING Country LIKE 'United%'  -- Filters countries starting with “United”
ORDER BY InfectedPopulationPercentage DESC;


------------------------------------------------------------
--  REGIONAL / CONTINENTAL COMPARISON
-- Shows highest death rate compared to population for regions
------------------------------------------------------------

SELECT Country, population, 
       MAX(CAST(total_deaths AS INT)) AS TotalDeathCount, 
       MAX((total_deaths/population))*100 AS TotalDeathPercentage
FROM ProjectData1.dbo.CovidDeaths
GROUP BY Country, population
HAVING Country IN ('World','Europe','North America','European Union',
                   'South America','Asia','Africa','Oceania','International')
ORDER BY TotalDeathPercentage DESC;


------------------------------------------------------------
--  COUNTRY-LEVEL DEATH RATES (Excluding Regional Aggregates)
------------------------------------------------------------

SELECT Country, population, 
       MAX(CAST(total_deaths AS INT)) AS TotalDeathCount, 
       MAX((total_deaths/population))*100 AS TotalDeathPercentage
FROM ProjectData1.dbo.CovidDeaths
GROUP BY Country, population
HAVING Country NOT IN ('World','Europe','North America','European Union',
                       'South America','Asia','Africa','Oceania','International')
ORDER BY TotalDeathPercentage DESC;


------------------------------------------------------------
--  GLOBAL NUMBERS BY DATE
-- Aggregates daily global new cases and deaths
------------------------------------------------------------

SELECT date, 
       SUM(new_cases) AS Total_New_Cases,
       SUM(new_deaths) AS Total_New_Deaths, 
       (SUM(new_deaths)/SUM(population)) * 100 AS DeathPercentage
FROM ProjectData1..CovidDeaths
GROUP BY date, country
HAVING country IN ('World','Europe','North America','European Union',
                   'South America','Asia','Africa','Oceania','International')
ORDER BY 1,2;


------------------------------------------------------------
--  TOTAL POPULATION VS VACCINATIONS
-- Joins deaths and vaccination tables by Country and Date
------------------------------------------------------------

SELECT dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations
FROM ProjectData1..CovidDeaths dea
JOIN ProjectData1..CovidVaccinations vac
  ON dea.country = vac.country 
 AND dea.date = vac.date
WHERE dea.continent IS NOT NULL  -- Filters out aggregate rows like 'World'
ORDER BY 1,2,3;


------------------------------------------------------------
-- ROLLING VACCINATION COUNT (Using Window Function)
-- Calculates cumulative vaccinations over time for each country
------------------------------------------------------------

SELECT dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations, 
       SUM(CAST(vac.new_vaccinations AS FLOAT)) 
           OVER (PARTITION BY dea.Country ORDER BY dea.country, dea.date) AS RollingCount
-- (RollingCount / population) * 100 → % of population vaccinated
FROM ProjectData1..CovidDeaths dea
JOIN ProjectData1..CovidVaccinations vac
  ON dea.country = vac.country 
 AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY 2,3;


------------------------------------------------------------
--  USING A CTE (Common Table Expression)
-- Wraps rolling calculation for cleaner percentage calculation
------------------------------------------------------------

WITH PopvsVac (Continent, Country, Date, Population, New_Vaccination, RollingCount) AS 
(
SELECT dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations, 
       SUM(CAST(vac.new_vaccinations AS FLOAT)) 
           OVER (PARTITION BY dea.Country ORDER BY dea.country, dea.date) AS RollingCount
FROM ProjectData1..CovidDeaths dea
JOIN ProjectData1..CovidVaccinations vac
  ON dea.country = vac.country 
 AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
)
-- Final output showing vaccination percentage
SELECT *, (RollingCount / Population) * 100 AS PercentageVaccinated
FROM PopvsVac;


------------------------------------------------------------
--  TEMP TABLE FOR VACCINATION PERCENTAGE
-- Stores intermediate vaccination data for reuse
------------------------------------------------------------

DROP TABLE IF EXISTS #PercentPopulationVaccinated;

CREATE TABLE #PercentPopulationVaccinated
(
    Continent NVARCHAR(255),
    Location NVARCHAR(255),
    Date DATETIME,
    Population NUMERIC,
    New_Vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

-- Insert rolling vaccination data
INSERT INTO #PercentPopulationVaccinated
SELECT dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations, 
       SUM(CAST(vac.new_vaccinations AS FLOAT)) 
           OVER (PARTITION BY dea.Country ORDER BY dea.country, dea.date) AS RollingCount
FROM ProjectData1..CovidDeaths dea
JOIN ProjectData1..CovidVaccinations vac
  ON dea.country = vac.country 
 AND dea.date = vac.date;

-- Calculate % vaccinated from temp table
SELECT *, (RollingPeopleVaccinated / Population) * 100 AS PercentageVaccinated
FROM #PercentPopulationVaccinated;


------------------------------------------------------------
--  CREATE A VIEW FOR VISUALIZATION TOOLS
-- Reusable view for Power BI / Tableau dashboards
------------------------------------------------------------

CREATE VIEW PercentPopulationVaccinated AS 
SELECT dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations, 
       SUM(CAST(vac.new_vaccinations AS FLOAT)) 
           OVER (PARTITION BY dea.Country ORDER BY dea.country, dea.date) AS RollingCount
FROM ProjectData1..CovidDeaths dea
JOIN ProjectData1..CovidVaccinations vac
  ON dea.country = vac.country 
 AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

-- View contents
SELECT * FROM PercentPopulationVaccinated;


------------------------------------------------------------
--  ALTERING AND UPDATING TABLE STRUCTURE
-- Adds derived columns and cleans up data
------------------------------------------------------------

/*
   Adds a new column `total_cases` derived from `total_cases_per_million`
   Formula: (total_cases_per_million * population) / 1,000,000
*/

SELECT Country, population, total_cases_per_million, 
       ((total_cases_per_million * population) / 1000000) AS Total_Cases
FROM CovidDeaths;

-- Add new column
ALTER TABLE CovidDeaths
ADD total_cases BIGINT;

-- Populate with computed values
UPDATE ProjectData1..CovidDeaths
SET total_cases = (total_cases_per_million * population) / 1000000;

-- Replace zero values with NULL for better aggregation
UPDATE ProjectData1..CovidDeaths
SET total_cases = NULL
WHERE total_cases = 0;

UPDATE ProjectData1..CovidDeaths
SET total_deaths = NULL
WHERE total_deaths = 0;

-- Verify updates
SELECT Country, population, total_cases_per_million, total_cases
FROM CovidDeaths;

-- Add new continent column for classification
ALTER TABLE CovidDeaths
ADD continent VARCHAR(50);


------------------------------------------------------------
-- MANUAL MAPPING OF COUNTRIES TO CONTINENTS
------------------------------------------------------------

-- Clear continent data for aggregate rows like 'World' or 'Regions'
UPDATE CovidDeaths
SET continent = NULL
WHERE country IN (
    'World','Europe','North America','European Union','South America','Asia',
    'Africa','Oceania','International','World excl. China',
    'World excl. China and South Korea','World excl. China, South Korea, Japan and Singapore',
    'Asia excl. China','European Union (27)','England and Wales',
    'High-income countries','Upper-middle-income countries',
    'Lower-middle-income countries','Low-income countries',
    'Summer Olympics 2020','Winter Olympics 2022'
);

-- Map each country to its corresponding continent
UPDATE CovidDeaths
SET continent = CASE 
    WHEN country IN ( ... ) THEN 'Asia'
    WHEN country IN ( ... ) THEN 'Europe'
    WHEN country IN ( ... ) THEN 'North America'
    WHEN country IN ( ... ) THEN 'South America'
    WHEN country IN ( ... ) THEN 'Africa'
    WHEN country IN ( ... ) THEN 'Oceania'
    ELSE continent
END;

-- Verify continent mapping
SELECT country, continent 
FROM ProjectData1..CovidDeaths;


----------------------------------------------------------------------------------
-- DATA CLEANING & EXPLORATION COMPLETE
-- The dataset is now standardized, aggregated, and ready for visualization.
----------------------------------------------------------------------------------
