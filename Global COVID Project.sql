/*
Queries using the dataset from <https://ourworldindata.org/covid-deaths> split in to
two tables: global_covid_vaccination table and global_covid_death.
*/

-- First we will just look at the tables.
select top 10 * 
from covid..global_covid_death;

SELECT TOP 10 *
FROM covid..global_covid_vaccination
WHERE location like '%states%';

-- I want to see the three big numbers from all of COVID reporting before the vaccines 
-- were available: cases, deaths, an percent positivity.
-- Total Cases vs Total Deaths, showing % of people who have died out of the total positive cases over time in the US
SELECT 
	location, date, 
	total_cases as TotalPositiveCases, 
	total_deaths as TotalCovidDeaths,
	ROUND((total_deaths / total_cases)*100, 3) as PercentDeathsOutOfTotalCases
FROM covid..global_covid_death
WHERE location like '%states%'
ORDER BY 1,2;

-- Now we will look at the big picture: how do the countries of the world compare when we look at
-- the percent positivity. We order by the percent positivity below.
-- Percentage of population that tested positive for covid per country
SELECT
	location, 
	MAX(total_cases) as TotalCovidCases, 
	MAX(total_deaths) as TotalCovidDeaths,
	ROUND((MAX(total_cases)/population)*100, 3) as PercentPopPositiveCovidTest
FROM covid..global_covid_death
WHERE location <> continent					-- there's a "continent" entry that provides the sum of all countries on a continent
GROUP BY location, population
ORDER BY 4 desc;

-- Since vaccines are being rolled out, we want to see the comparison of the previous table with information
-- about the vaccines rollout involved.
-- It is being ordered by decreasing values of the percent of people who tested positive for COVID19.
-- Positive cases, total deaths, percent of population that tested positive, amount vaccinated, and percent vaccinated
SELECT
	d.location, MAX(d.total_cases) as TotalCovidCases,
	MAX(d.total_deaths) as TotalCovidDeaths,
	ROUND((MAX(d.total_cases)/d.population)*100, 3) as PercentPopPositiveCovidTest,
	MAX(v.people_fully_vaccinated) as TotalVaccinated,
	ROUND((MAX(v.people_fully_vaccinated)/d.population)*100, 3) as PercentVaccinated
FROM covid..global_covid_death d
JOIN covid..global_covid_vaccination v
	ON d.location = v.location
WHERE d.continent is not null
GROUP BY d.location, d.population
ORDER BY 4 desc;


--Exploring the differences between total_vaccinations, new_vaccinations, people_fully_vaccinated, and people_vaccinated.
-- When I see the names of the columns, I would think that they would be equal OR I could use a SUM function to see
-- the same numbers.

SELECT	location,
		MAX(cast(total_vaccinations as bigint)) as total_vax_TotalVax, 
		SUM(cast(new_vaccinations as bigint)) as total_vax_NewVax,
		MAX(cast(people_fully_vaccinated as bigint)) as fully_vaxd_PeopleFullyVax,
		MAX(cast(people_vaccinated as bigint)) as fully_vaxd_PeopleVax
FROM covid..global_covid_vaccination
GROUP BY location
ORDER BY location;

-- Conclusions:
-- Seems like total_vaccinations and new_vaccinations refer to the number of shots. Not people vaccinated.
-- people_vaccinated must refer to those with at least one shot, while fully_vaccinated are the people with 2
-- shots are (presumably) 2 weeks after last shot.
-- The sum of new_vaccinations should equal total_vaccinations, so there must be some critical null values in new_vaccinations.
-- Checking for null values below.
SELECT	COUNT(*) - COUNT(total_vaccinations) as [Null TotalVax],
		COUNT(*) - COUNT(new_vaccinations) as [Null NewVax],
		COUNT(*) - COUNT(people_fully_vaccinated) as [Null PeopleFullyVaxd],
		COUNT(*) - COUNT(people_vaccinated) as [Null PeopleVaxd]
FROM covid..global_covid_vaccination
WHERE location like '%states%';

-- Now lets take a look at those specific variables in the table.
SELECT top 15	date,
				total_vaccinations,
				new_vaccinations,
				people_fully_vaccinated,
				people_vaccinated
FROM covid..global_covid_vaccination
WHERE year(date) > 2020 AND location like '%states%';
-- Now we know that using SUM on the new_vaccinations isn't the best way to get an accurate picuture
-- of the total vaccinations given out.


-- The below query examines the number of shots and cummulative shots each continent has given per day.
-- Uses: CTE (common table expressions) and an OVER Clause with a Partition By.
WITH ContinentDailyShots (continent, date, NumberofShots)
AS (
SELECT continent,
		date,
		SUM(CONVERT(int,new_vaccinations)) as NumberOfShots
FROM covid..global_covid_vaccination
WHERE continent is not null
GROUP BY continent, date
)
SELECT *,
	SUM(NumberOfShots) OVER (PARTITION BY continent ORDER BY continent, date) as CummulativeShots
FROM ContinentDailyShots
ORDER BY 1,2;

-- Highest Death Count per continent.
-- Interesting thing about the data: there is a location representing the toal numbers for each continent.
SELECT	location,
		MAX(CONVERT(int,total_deaths)) as TotalDeath
FROM covid..global_covid_death
WHERE continent is null
GROUP BY location
ORDER BY 2 desc;

/*
**Recreating Graphs**
The below queries aim to recreate the popular graphs shown on search results, news reporting on COVID, and
other places when talking about COVID190 in the USA. The direct inspiration came from using Google to search
for "us covid cases" and seeing the graphs displayed, which often used the New York Times' visualizations.
These will all be visualized in Public Tableau under my account <https://public.tableau.com/app/profile/connor1260>.
*/

-- New cases vs time with a line on top representing the "7day average".
SELECT	location, 
		date, 
		new_cases,
		(SUM(CONVERT(int,new_cases)) OVER (Partition BY location ORDER BY location, date
										ROWS BETWEEN 6 PRECEDING AND CURRENT ROW))/7 as SevenDayAvg
FROM covid..global_covid_death
WHERE location like '%states%';

-- Deaths vs time with a line representing the 7day average.
SELECT	location,
		date, 
		new_deaths,	
		(SUM(CONVERT(int,new_deaths)) OVER (Partition BY location ORDER BY location, date
										ROWS BETWEEN 6 PRECEDING AND CURRENT ROW))/7 as SevenDayAvg
FROM covid..global_covid_death
WHERE location like '%states%';

--Vaccinations. One dose, fully_vaccinated, % of population for both.
SELECT location,date,
		people_vaccinated,
		people_vaccinated_per_hundred as PercentOneDose,
		people_fully_vaccinated,
		people_fully_vaccinated_per_hundred as PercentFullyVaxed
FROM covid..global_covid_vaccination
WHERE location like '%states%'
ORDER BY 2;

-- Tests taken, positive tests, percent positivity.
WITH Positivity (location, date, TestsTaken, PositiveTests, PositivityRate)
AS (
SELECT location, date,
		CONVERT(int,new_tests) as TestsTaken,
		CAST(CONVERT(int,new_tests)*CONVERT(decimal(4,3),positive_rate) as int) as PositiveTests,
		ROUND(CONVERT(decimal(4,3),positive_rate)*100,2) as PositivityRate
FROM covid..global_covid_vaccination
WHERE location like '%states%')
SELECT location, date,
	(SUM(TestsTaken) OVER (Partition BY location ORDER BY location, date
								ROWS BETWEEN 6 PRECEDING AND CURRENT ROW))/7 as TestsTaken7DayAvg,
	(SUM(PositiveTests) OVER (Partition BY location ORDER BY location, date
								ROWS BETWEEN 6 PRECEDING AND CURRENT ROW))/7 as PositiveTests7DayAvg,
	PositivityRate
FROM Positivity
ORDER BY location, date;


-- Global Vaccine Rollout, graph shared by Winnie Byanyima on Twitter. Added on people fully vaxd to help understand it.
-- The graph aimed to show the disparity between countries, often by continent, when it came to vaccinations.
SELECT location, 
	MAX(CONVERT(numeric,total_vaccinations_per_hundred)) as TotalVaccinesPerHundred,
	MAX(CONVERT(numeric,people_fully_vaccinated_per_hundred)) as PeopleFullyVaxdPerHundred
FROM covid..global_covid_vaccination
WHERE continent is not null
GROUP BY location
ORDER BY 2 desc;