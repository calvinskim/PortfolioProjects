/* This is a SQL file to showcase my skills.

Data comes from https://ourworldindata.org/covid-deaths

Skills used in this file: Joins, CTEs, temp tables, window functions, aggregate functions, creating views, and converting data types

*/

-- create temp table of the main data that will be worked with throughout this file
drop table if exists #covid_deaths_vax
create table #covid_deaths_vax	(
		continent nvarchar(255)
		,location nvarchar(255)
		,date datetime
		,population numeric
		,new_cases numeric
		,new_deaths numeric
		,new_vaccinations numeric
		,total_cases numeric
		,total_deaths numeric
		,total_vaccinations numeric
);

insert into #covid_deaths_vax
select		cd.continent
			,cd.location 
			,cd.date
			,cd.population
			,cd.new_cases
			,cd.new_deaths
			,cv.new_vaccinations
			,cd.total_cases
			,cd.total_deaths
			,cv.total_vaccinations
from		portfolio_project_1..covid_deaths cd
left join	portfolio_project_1..covid_vaccinations cv
on			cd.location = cv.location
and			cd.date = cv.date
where		cd.continent is not null

-- taking a look at how each continent is doing with total cases, total deaths, total vaccination, and population
select		continent
			,sum(new_cases)			as total_cases
			,sum(new_deaths)		as total_deaths
			,sum(new_vaccinations)	as total_vaccinations
			,max(population)		as population
from		#covid_deaths_vax cdv
group by	continent
order by	continent

-- taking a look at how each country is doing with total cases, total deaths, total vaccinations, and population
select		continent 
			,location
			,sum(new_cases)			as total_cases
			,sum(new_deaths)		as total_deaths
			,sum(new_vaccinations)	as total_vaccinations
			,max(population)		as population
from		#covid_deaths_vax cdv
group by	continent, location
order by	continent, location

-- using the counts per location table per day in a CTE, look at how vaccination rates (assuming 2 doses per person) is affecting the death rate and case rate (limiting it to United States for simplicity)
with covid_death_vax_rate (location, date, case_rate, death_rate, vax_rate) as (
	select	location
			,date
			,total_cases/population*100				as case_rate
			,total_deaths/population*100			as death_rate
			,(total_vaccinations/2)/population*100	as vax_rate
	from	#covid_deaths_vax
	where	location like '%states%'
) 
select		*
from		covid_death_vax_rate
order by	date

-- the above look doesnt really showcase if vax helps so this next table looks into comparing day over day change with the vax rate staying the same
with covid_death_vax_rate (location, date, dod_case_change, dod_death_rate, vax_rate) as (
	select	location
			,date
			,new_cases
			,new_deaths
			,(total_vaccinations/2)/population*100	as vax_rate
	from	#covid_deaths_vax
	where	location like '%states%'
)
select		*
from		covid_death_vax_rate
order by	date

-- showing continent with highest death count per population using a mix of window functinos and aggregate functions
select		distinct continent
			,sum(loc_pop_cnt)	as cont_pop_cnt
			,sum(loc_death_cnt)	as cont_death_cnt
			,sum(loc_death_cnt)/sum(loc_pop_cnt) * 100	as cont_death_rate
from		(
			select	distinct continent
					,location
					,max(population) over (partition by location)	loc_pop_cnt
					,max(cast(total_deaths as int)) over (partition by location)	loc_death_cnt
			from	portfolio_project_1..covid_deaths cd
			where	continent is not null
			) a
group by	continent
order by	cont_death_rate desc

-- create a view for use in later visuals in portfolio
drop view if exists covid_case_death_vax
create view covid_case_death_vax as
select		cd.continent
			,cd.location
			,cd.date
			,population
			,cd.new_cases
			,cd.new_deaths as new_deaths
			,cv.new_vaccinations as new_vaccinations
			,cd.total_cases
			,cd.total_deaths
			,sum(cast(case when cv.date <= cd.date then coalesce(cv.new_vaccinations, 0) end as numeric)) over (partition by cd.location)	as total_vaccinations
from		portfolio_project_1..covid_deaths cd
left join	portfolio_project_1..covid_vaccinations cv
on			cd.location = cv.location
and			cd.date	= cv.date
where		cd.continent is not null