# Stata command: `ineqstats`

## Version
November 2023

## Introduction
`ineqstats` is a Stata program developed for summarizing survey micro-data with weighted observations across various distributional dimensions. It handles large data volumes, including information from different areas (countries or regions), over various time periods. This command is especially useful for comprehensive analysis of income and wealth distribution.

## Features
- Generates summarized distributions in percentiles with enhanced resolution at the upper end.
- Computes key distributional indices like the Gini coefficient.
- Calculates group shares such as the top 1% and 10%, the middle 40%, and the Bottom 50%.
- Fits a Pareto distribution to the top tail of the income distribution.
- Simulates marginal taxes on total income or wealth.
- Provides detailed income composition for each group.


### Inputs
- **summarize**: Required to enable other options.
- **areas (string)**: Specifies the areas (countries or regions) included in the analysis.
- **time (numlist, max=2)**: Specifies the analysis period, with numlist indicating start and end years.
- **decomposition (string)**: Specifies the components of total income or wealth for decomposition.
- **svypath (string)**: Indicates the path to the survey data.
- **weight (string)**: Defines the variable used as weights in the analysis.
- **export (string)**: Sets the path for exporting the output.

### Options
- **smoothtop**: Applies smoothing to the top of the income distribution.
- **edad (numlist, max=2)**: Restricts the analysis to specific age groups.
- **mrates (numlist)**: Simulates a marginal tax on total income or wealth with defined tax rates.
- **mthresholds (numlist)**: Simulates a marginal tax with minimum thresholds for each tax bracket.

## Description
`ineqstats` provides comprehensive distributional statistics, including detailed analysis of income or wealth distribution across different population segments and time periods. It includes advanced options for tax simulations and age-specific analyses, making it a versatile tool for economic and social research.

## Examples
ineqstats summarize, areas("USA BRA") time(2000 2017) decomposition("capital" "labor") weight("pop_weight") export("mainfolder/subfolder")

## Remarks
Developed in 2022 by Ignacio Flores.

