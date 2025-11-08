-- 🔹 View all records from CovidDeaths table
-- "ProjectData1" is the database, "CovidDeaths" is the table.
-- Ordering by column 2 and 3 (typically location/country and date)
Select * 
from ProjectData1..CovidDeaths
order by 2,3;

-- 🔹 View all records from CovidVaccinations table
-- Used later to join with deaths data for analysis
Select * 
from ProjectData1..CovidVaccinations
order by 2;

------------------------------------------------------------
-- Selected Data that we are going to be using
------------------------------------------------------------

-- 🔹 Selecting key columns we’ll use for analysis
Select Country, date, total_cases, new_cases, total_deaths, population
from ProjectData1.dbo.CovidDeaths
where country in ('Bangladesh','Oman')
order by 1,2;

------------------------------------------------------------
-- Looking at Total Cases vs Total Deaths
-- Calculates the likelihood (%) of dying if you contract COVID-19
------------------------------------------------------------

Select Country, date, total_cases, total_deaths, 
       (total_deaths/total_cases)*100 as DeathPercentage
from ProjectData1.dbo.CovidDeaths
where country IN ('Bangladesh','Oman')
order by 1,2;

------------------------------------------------------------
-- Looking at Total Cases vs Population
-- Shows what percentage of the population got COVID
------------------------------------------------------------

Select Country, date, population, total_cases, 
       (total_cases/population)*100 as CasePercentage
from ProjectData1.dbo.CovidDeaths
where country IN ('Bangladesh','Oman')
order by 1,2;

------------------------------------------------------------
-- Countries with Highest Infection Rate compared to Population
-- Finds max infection count and percentage of population infected
------------------------------------------------------------

Select Country, population, 
       max(total_cases) as HighestInfectionCount, 
       max((total_cases/population))*100 as InfectedPopulatePercentage
from ProjectData1.dbo.CovidDeaths
Group by country, population
having country like 'United%'  -- filters for countries starting with “United”
order by InfectedPopulatePercentage desc;

------------------------------------------------------------
-- Continents (or regions) with Highest Death Rate compared to Population
-- Using “World”, “Europe”, etc. which are aggregated regions in the dataset
------------------------------------------------------------

Select Country, population, 
       max(cast(total_deaths as int)) as TotalDeathCount, 
       max((total_deaths/population))*100 as TotalDeathPercentage
from ProjectData1.dbo.CovidDeaths
Group by country,population
having country IN ('World','Europe','North America','European Union',
                   'South America','Asia','Africa','Oceania','Internation')
order by TotalDeathPercentage desc;

------------------------------------------------------------
-- Countries with Highest Death Rate compared to Population (excluding regions)
------------------------------------------------------------

Select Country, population, 
       max(cast(total_deaths as int)) as TotalDeathCount, 
       max((total_deaths/population))*100 as TotalDeathPercentage
from ProjectData1.dbo.CovidDeaths
Group by country,population
having country NOT IN ('World','Europe','North America','European Union',
                       'South America','Asia','Africa','Oceania','Internation')
order by TotalDeathPercentage desc;

------------------------------------------------------------
-- Global Numbers by Date
-- Aggregates new cases and deaths to get daily global stats
------------------------------------------------------------

Select date, 
       Sum(new_Cases) as total_new_cases,
       Sum(new_Deaths) as total_new_deaths, 
       (sum(new_Deaths)/sum(population)) * 100 as DeathPercentage
from ProjectData1..CovidDeaths
Group by date,country
having country IN ('World','Europe','North America','European Union',
                   'South America','Asia','Africa','Oceania','Internation')
order by 1,2;

------------------------------------------------------------
-- Total Population vs Vaccinations
-- Joining deaths and vaccination datasets by country and date
------------------------------------------------------------

Select dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations
from ProjectData1..CovidDeaths dea
Join ProjectData1..CovidVaccinations vac
  on dea.country = vac.country 
 and dea.date = vac.date
where dea.continent is not NUll  -- filters out summary rows like 'World'
order by 1,2,3;

------------------------------------------------------------
-- Using Window Function for Rolling Vaccination Count
-- Calculates cumulative total vaccinations over time per country
------------------------------------------------------------

Select dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations, 
       sum(Cast(vac.new_vaccinations as float)) 
           over (Partition by dea.Country order by dea.country,dea.date) as RollingCount
-- (rollingcount/population)*100 would give percent vaccinated
from ProjectData1..CovidDeaths dea
Join ProjectData1..CovidVaccinations vac
  on dea.country = vac.country 
 and dea.date = vac.date
where dea.continent is not NUll
order by 2,3;

------------------------------------------------------------
-- Using CTE (Common Table Expression)
-- Same idea as before, but wrapped in a CTE for cleaner calculation
------------------------------------------------------------

With PopvsVac (Continent, country, Date, Population, new_vaccination, RollingCount) as 
(
Select dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations, 
       sum(Cast(vac.new_vaccinations as float)) 
           over (Partition by dea.Country order by dea.country,dea.date) as RollingCount
from ProjectData1..CovidDeaths dea
Join ProjectData1..CovidVaccinations vac
  on dea.country = vac.country 
 and dea.date = vac.date
where dea.continent is not NUll
)
-- Final select calculates % of population vaccinated
select *, (rollingCount/population)*100 as PercentageCount
from PopvsVac;

------------------------------------------------------------
-- Temporary Table for Vaccination Percentage
-- Stores intermediate results in a temp table for reuse
------------------------------------------------------------

Drop table if exists #PercentPopulationVaccinated;

Create Table #PercentPopulationVaccinated
(
Continent nvarchar(255),
Location nvarchar(255),
Date datetime,
Population numeric,
New_Vaccinations numeric,
RollingPeopleVaccinated numeric
);

-- Insert rolling vaccination data
Insert into #PercentPopulationVaccinated
Select dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations, 
       sum(Cast(vac.new_vaccinations as float)) 
           over (Partition by dea.Country order by dea.country,dea.date) as RollingCount
from ProjectData1..CovidDeaths dea
Join ProjectData1..CovidVaccinations vac
  on dea.country = vac.country 
 and dea.date = vac.date;

-- Calculate vaccination % from temp table
select *, (RollingPeopleVaccinated/population)*100 as PercentageCount
from #PercentPopulationVaccinated;

------------------------------------------------------------
-- Create a View to Store Data for Future Visualizations
------------------------------------------------------------

Create View PercentPopulationVaccinated as 
select dea.continent, dea.country, dea.date, dea.population, vac.new_vaccinations, 
       sum(Cast(vac.new_vaccinations as float)) 
           over (Partition by dea.Country order by dea.country,dea.date) as RollingCount
from ProjectData1..CovidDeaths dea
Join ProjectData1..CovidVaccinations vac
  on dea.country = vac.country 
 and dea.date = vac.date
where dea.continent is not NUll;

-- View contents
select * from PercentPopulationVaccinated;

------------------------------------------------------------
-- Altering and Updating Table
-- Adding new columns and cleaning data
------------------------------------------------------------

/* Adds a new column for total_cases, derived from total_cases_per_million
   Formula: (total_cases_per_million * population) / 1,000,000
*/

select Country, population, total_cases_per_million, 
       ((total_cases_per_million*population) / 1000000) as Total_Cases
from CovidDeaths;

-- Add the new column to the table
ALTER TABLE CovidDeaths
ADD total_cases BIGINT;

-- Populate new column with computed values
Update ProjectData1..CovidDeaths
Set total_cases = (total_cases_per_million * population) / 1000000;

-- Replace zero values with NULL for better aggregation accuracy
Update ProjectData1..CovidDeaths
Set total_cases = null
where total_cases = 0;

Update ProjectData1..CovidDeaths
Set total_deaths = null
where total_deaths = 0;

-- Verify updates
select Country,population, total_cases_per_million, Total_Cases
from CovidDeaths;

-- Add a new column for continent classification
ALTER TABLE CovidDeaths
ADD continent varchar(50);

------------------------------------------------------------
-- Manual Mapping of Countries to Continents using CASE statements
-- Assigns continent values to each country
------------------------------------------------------------

-- Clear any existing “continent” data for aggregate rows like 'World'
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
SET Continent = CASE 
    WHEN country IN ( ... ) THEN 'Asia'
    WHEN country IN ( ... ) THEN 'Europe'
    WHEN country IN ( ... ) THEN 'North America'
    WHEN country IN ( ... ) THEN 'South America'
    WHEN country IN ( ... ) THEN 'Africa'
    WHEN country IN ( ... ) THEN 'Oceania'
    ELSE Continent
END;

-- Verify continent mapping
select country, continent from ProjectData1..CovidDeaths;
