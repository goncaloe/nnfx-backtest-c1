# nnfx-backtest

Expert Advisor to backtest confirmation indicators in NNFX way

## How to Use:

* Put the NNFX_Backtest.mq4 in MQL4/Experts folder
* Refresh list of Expert Advisors to compile the EA.
* Open Strategy Tester in MetaTrader4 and select Expert Advisor NNFX_Backtest.ex4
* Configure like below image:
![ea strategy tester](./ea_strategy_tester.png)
* Click on Expert Properties and fill IndicatorPath, IndicatorType and IndicatorParams (double click in Value column):
![ea properties](./ea_properties.png)
    * IndicatorPath: the name of compiled indicator relative to the root indicators directory (MQL4/Indicators/). If the indicator is located in subdirectory, for example, in MQL4/Indicators/Examples, its name must be specified as "Examples\\indicator_name".
    * IndicatorType: Dropdown of the indicator we want test.
    * IndicatorParams: comma-separated list of parameters. If you omit parameters on the right, the EA will apply default values of these parameters. Leave blank to test with all default parameters.
* Click on start. 
![ea run](./ea_run.png)

If the indicator is not shown in chart, check if the journal tab shows any error

## Generic Indicators:

In Expert Properties set IndicatorType to one of these values: 

* Crossover: to test indicators that gives sinal when two lines crosses. Fill IndicatorIndex1 and IndicatorIndex2 to specify lines of indicator to cross.
* Zeroline: test indicators that gives sinals when the value cross 0 line. Fill IndicatorIndex1 to specify the line of indicator to cross zero line.

## Test Built-In Indicators:

There are several built-in indicators available:

Indicator | Type  | Default Params
--------- | ----- | --------------
Absolute_Strength_Histogram | Crossover | 0,9,1,4,0,3,3
Accelerator_LSMA | Zeroline | 5,34,5
Vortex | Crossover | 14
RVI | Crossover | 10
Aroon_Horn | Crossover | 10
ASO | Crossover | 10,0
SSL | Crossover | 10,0
TSI | Zeroline | 5,8
Schaff_Trend_Cycle | Crossover | 10,23,50
Waddah_Attar_Explosion | Others | 150,30,15,15

> Note: Each of these indicators has been prepared for a specific version of indicator. If you have a different version, ask me to include it in EA.

## Backtest Results:

To see the report of backtest you can check the Report tab. You also can see how many orders where closed on opposite signal in Journal tab.
Winrate is calculated by wins / (wins + losses) but all wins or losses of opposite sinal only counts half.

![ea results](./ea_results.png)

## Optimization:

In order to search for the best parameters for your indicator you can use the optimization. To do this put #1, #2,... as parameter you will use optimization.
In the example above you could use `0,#1,#2,#3,3` in IndicatorParams where #1 is Input1, #2 is Input2, #3 is Input3:

![ea optimization](./ea_optimization.png)

Click on checkbox optimization and start test.

![ea optimization results](./ea_optimization_results.png)

As you can see the test with Input1=3, Input2=7, Input3=8  (parameters `0,3,7,8,3`) got best results.