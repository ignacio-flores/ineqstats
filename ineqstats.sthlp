{smcl}
{* *! version v0.0.0.9000 nov2023}{...}
{title:Title}
{phang}
{bf:ineqstats} {hline 2} Summarizes Survey Micro-Data in Distributional Dimensions

{marker syntax}{...}
{title:Syntax}

{cmd:ineqstats} {it:summarize} {cmd:,} {opt ar:eas (string)} {opt ti:me (numlist, max=2)} {opt  dec:omposition}(string) {opt weight}(string) {opt exp:ort}(string) {opt svyp:ath}(string) , [options]


{synoptset 30 tabbed}{...}
{synopthdr}
{synoptline}

{syntab:Inputs}

{synopt:{it:summarize}}required to enable other options.

{synopt:{opth ar:eas (string)}}specifies the areas (countries or regions) included in the analysis.{p_end}

{synopt:{opth ti:me (numlist max=2)}}specifies the analysis period, with {it:numlist} indicating start and end years.{p_end}

{synopt:{opth dec:omposition (string)}}specifies the components of total income or wealth for decomposition.{p_end}

{synopt: {opth svyp:ath (string)}}indicates the path to the survey data.{p_end}

{synopt: {opth weight (string)}}defines the variable used as weights in the analysis.{p_end}

{synopt: {opth exp:ort (string)}}sets the path for exporting the output.{p_end}


{syntab:Options}


{synopt:{opt smooth:top}}applies smoothing to the top of the income distribution.{p_end}

{synopt:{opt edad}(numlist, max=2)}restricts the analysis to specific age groups. One number retains observations above that age, and two numbers retain observations within the age range. The variable 'edad' must be used for this option.{p_end}

{syntab:Tax simulation}

{synopt:{opt mrat:es (numlist)}}simulates a marginal tax on total income or wealth. {opt MRATes} define a series of tax rates. The number of rates and thresholds must be equal.{p_end}

{synopt:{opt mthr:esholds (numlist)}}simulates a marginal tax on total income or wealth. {opt MTHResholds} defines minimum thresholds for each tax bracket. The number of rates and thresholds must be equal.{p_end}

{synoptline}

{marker description}{...}
{title:Description}

{p 4 5} {cmdab:ineqstats}  is a Stata program designed for summarizing survey micro-data with weighted observations across various distributional dimensions. It is capable of handling large data volumes, including information from different areas such as countries or regions, over various time periods.

{p 4 5} This command provides comprehensive distributional statistics, generating summarized distributions in percentiles with enhanced resolution at the upper end. It computes key distributional indices like the Gini coefficient and group shares such as the top 1% and 10%, the middle 40% and the Bottom 50%. The command also allows for fitting a Pareto distribution to the top tail of the income distribution. It also allows simulations of marginal taxes on total income or wealth, defined as the sum of variables specified in the {opt decomposition} option. When multiple variables are used for {opt decomposition}, the summarized information displays the income composition for each group, including both in percentiles and in broader groups.

remarks
{p 4 5} Developed in 2022 by Ignacio Flores, {cmd:ineqstats}

examples
{p 4 5} {cmd:ineqstats} {it:summarize}, areas("USA BRA") time(2000 2017) decomposition("capital" "labor") weight("pop_weight") export("mainfolder/subfolder")
