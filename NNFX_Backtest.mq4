//+---------------------------------------------------------------------------|
//|                                                        NNFX_backtest.mq4  |
//|                                                       by Gonçalo Esteves  |
//|                                https://github.com/goncaloe/nnfx-backtest  |
//|                                                          August 17, 2019  |
//|                                                                     v1.8  |
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2019, Gonçalo Esteves"
#property strict

#define FLAT 0
#define LONG 1
#define SHORT 2
#define PARAM_EMPTY 999.0

enum IndicatorTypes {
   ZeroLine = 1,
   Crossover = 2,
   MovingAvarage = 3,
};

enum OptimizationCalcTypes {
   Winrate = 0,
   Takeprofit = 1,
   Stoploss = 2,
   WinsBeforeTP = 3,
   LossesBeforeSL = 4,
};

sinput int ATRPeriod = 14;
sinput int Slippage = 3;
sinput double RiskPercent = 2;
sinput int TakeProfitPercent = 100;
sinput int StopLossPercent = 150;
sinput bool ReopenOnOppositeSignal = true;
sinput OptimizationCalcTypes OptimizationCalcType = 0;
sinput string IndicatorName = "MyIndicator";
sinput IndicatorTypes IndicatorType = 1;
extern double IndicatorParam1 = PARAM_EMPTY;
extern double IndicatorParam2 = PARAM_EMPTY;
extern double IndicatorParam3 = PARAM_EMPTY;
extern double IndicatorParam4 = PARAM_EMPTY;
extern double IndicatorParam5 = PARAM_EMPTY;
extern double IndicatorParam6 = PARAM_EMPTY;
sinput int IndicatorIndex1 = 0;
sinput int IndicatorIndex2 = 1;


// GLOBAL VARIABLES:
double myATR;
double stopLoss;
double takeProfit;
int myTicket;
int myTrade;
int countTP = 0;
int countSL = 0;
int countWinsBeforeTP = 0;
int countLossesBeforeSL = 0;

void OnDeinit(const int reason){  
   updateBacktestResults();
   string text = StringConcatenate("WinsTP: ", countTP, "; LossesSL: ", countSL, "; WinsBeforeTP: ", countWinsBeforeTP, "; LossesBeforeSL: ", countLossesBeforeSL, "; Winrate: ", getNNFXWinrate());
   Print(text);
}

void OnTick()
{  
   checkTicket();
   
   checkForOpen();
}

double OnTester()
{
   switch(OptimizationCalcType){
      case 0:
         return getNNFXWinrate();
      case 1:
         return countTP;
      case 2:
         return countSL;
      case 3:
         return countWinsBeforeTP;
      case 4:
         return countLossesBeforeSL;        
   }
   return 0;
}

//+-SIGNAL FUNCTIONS-------------------------------------------------+

/*
return int: the signal of indicator
   FLAT: no sinal:
   LONG: long signal
   SHORT: short signal
for custom indicator uncomment only the indicator that we are testing     
*/
int getSignal()
{
   //Zeroline:
   //double indParams[] = {5, 34,5};
   //int signal = getIndicatorZerocrossSignal("Accelerator_LSMA_v2", indParams, 0);
   //Print(signal);
   
   //Crossover:
   //double indParams[] = {14};
   //int signal = getIndicatorCrossoverSignal("Vortex", indParams, 0, 1);
   //double indParams[] = {5, 34,5};
   //int signal = getIndicatorCrossoverSignal("Accelerator_LSMA_v2", indParams, 1, 0);
   //double indParams[] = {1,7,1,3,3};
   //return getIndicatorCrossoverSignal("Absolute_Strength_Histogram", indParams, 2, 3);
   //double indParams[] = {14};
   //int signal = getIndicatorCrossoverSignal("RVI", indParams, 0, 1);
   //double indParams[] = {14};
   //int signal = getIndicatorCrossoverSignal("Aroon_Horn", indParams, 0, 1);
   
   //MA:
   //return getIndicatorMASignal("TEMA", 25, 0);


   //try get signal by Properties of Expert:
   double indParams[6];
   parseIndicatorParams(indParams);
   
   if (IndicatorType == 1)
   {
      return getIndicatorZerocrossSignal(IndicatorName, indParams, IndicatorIndex1);
   }
   else if (IndicatorType == 2)
   {
      return getIndicatorCrossoverSignal(IndicatorName, indParams, IndicatorIndex1, IndicatorIndex2);
   }
   else if (IndicatorType == 3)
   {
      return getIndicatorMASignal(IndicatorName, indParams, IndicatorIndex1);
   }

   return FLAT;
}

int getIndicatorCrossoverSignal(string ind, double &params[], int buff1, int buff2)
{
   double v0Curr = iCustomArray(NULL, 0, ind, params, buff1, 1);
   double v0Prev = iCustomArray(NULL, 0, ind, params, buff1, 2);
   double v1Curr = iCustomArray(NULL, 0, ind, params, buff2, 1);
   double v1Prev = iCustomArray(NULL, 0, ind, params, buff2, 2);  
   int signal = FLAT;
   if(v0Prev < v1Prev && v0Curr > v1Curr){
      signal = LONG;
   }
   else if(v0Prev > v1Prev && v0Curr < v1Curr){
      signal = SHORT;
   }
   return signal;
}

int getIndicatorZerocrossSignal(string ind, double &params[], int buff)
{
   double vCurr = iCustomArray(NULL, 0, ind, params, buff, 1);
   double vPrev = iCustomArray(NULL, 0, ind, params, buff, 2);  
   int signal = FLAT;
   if(vPrev < 0 && vCurr >= 0){
      signal = LONG;
   }
   else if(vPrev > 0 && vCurr <= 0){
      signal = SHORT;
   }
   return signal;
}

int getIndicatorMASignal(string ind, double &params[], int buff)
{
   double vCurr = iCustom(NULL, 0, ind, params[0], buff, 1);
   double vPrev = iCustom(NULL, 0, ind, params[0], buff, 2);
   double vPrev2 = iCustom(NULL, 0, ind, params[0], buff, 3);
   
   int signal = FLAT;
   if(vCurr > vPrev && vPrev2 >= vPrev){
      signal = LONG;
   }
   else if(vCurr < vPrev && vPrev2 <= vPrev){
      signal = SHORT;
   }
   return signal;
}

// alias:
int getIndicatorMASignal(string ind, double period, int buff)
{
   double indParams[1];
   indParams[0] = period;
   return getIndicatorMASignal(ind, indParams, buff);
}


//+-TRADE FUNCTIONS-------------------------------------------------+

void checkForOpen(){
   if(!ReopenOnOppositeSignal && myTrade != FLAT){
      return;
   }
   
   int signal = getSignal();
   
   if(signal == FLAT){
      return;
   }
   
   if(ReopenOnOppositeSignal && myTrade != FLAT && myTrade != signal){
      double close = myTrade == LONG ? Bid : Ask;
      
      if(!OrderSelect(0, SELECT_BY_POS, MODE_TRADES)){
         return;   
      }
      
      if(!OrderClose(myTicket, OrderLots(), close, Slippage)){
         return;
      }
      
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit > 0){
         countWinsBeforeTP++;      
      }
      else {
         countLossesBeforeSL++; 
      }
      
      myTicket = -1;
      myTrade = FLAT;
   }
   
   if(myTrade != FLAT){
      return;
   }
   
   // calculate takeProfit and stopLoss
   updateValues();
   double myLots = getLots(stopLoss);
   
   if(signal == LONG){
      openTrade(OP_BUY, "Buy Order", myLots, stopLoss, takeProfit);
   }
   else if(signal == SHORT){
      openTrade(OP_SELL, "Sell Order", myLots, stopLoss, takeProfit);
   }
   
}


void openTrade(int signal, string msg, double mLots, double mStopLoss, double mTakeProfit)
{  
   double TPprice, STprice;
   
   if (signal==OP_BUY) 
   {
      myTicket = OrderSend(_Symbol,OP_BUY,mLots,Ask,Slippage,0,0,msg,0,0,Green);
      if (myTicket > 0)
      {
         myTrade = LONG;
         if (OrderSelect(myTicket, SELECT_BY_TICKET, MODE_TRADES) ) 
         {
            TPprice = Ask + mTakeProfit*Point;
            STprice = Ask - mStopLoss*Point;
            // Normalize stoploss / takeprofit to the proper # of digits.
            if (Digits > 0)
            {
              STprice = NormalizeDouble( STprice, Digits);
              TPprice = NormalizeDouble( TPprice, Digits); 
            }
		      if(!OrderModify(myTicket, OrderOpenPrice(), STprice, TPprice,0, LightGreen)){
               Print("OrderModify error ",GetLastError());
               return;
		      }
		   }
         
      }
   }
   else if (signal == OP_SELL) 
   {
      myTicket = OrderSend(_Symbol,OP_SELL,mLots,Bid,Slippage,0,0,msg,0,0,Red);
      if (myTicket > 0)
      {
         myTrade = SHORT;
         if (OrderSelect(myTicket,SELECT_BY_TICKET, MODE_TRADES) ) 
         {
            TPprice=Bid - mTakeProfit*Point;
            STprice = Bid + mStopLoss*Point;
            // Normalize stoploss / takeprofit to the proper # of digits.
            if (Digits > 0) 
            {
              STprice = NormalizeDouble( STprice, Digits);
              TPprice = NormalizeDouble( TPprice, Digits); 
            }
		      
		      if(!OrderModify(myTicket, OrderOpenPrice(), STprice, TPprice,0, LightGreen)){
               Print("OrderModify error ",GetLastError());
               return;
		      }
         }
       }
   }
}


// update myTicket and myTrade
void checkTicket(){
   myTicket = -1;
   myTrade = FLAT;
   if(OrdersTotal() >= 1){
      if(!OrderSelect(0, SELECT_BY_POS, MODE_TRADES)){
         return;   
      }
      int oType = OrderType();
      if(oType == OP_BUY){
         myTicket = OrderTicket();
         myTrade = LONG;   
      }
      else if(oType == OP_SELL){
         myTicket = OrderTicket();
         myTrade = SHORT;
      }
   }
}


//+-AUXILIAR FUNCTIONS----------------------------------------------+

void updateValues(){
   myATR = iATR(NULL, 0, ATRPeriod, 1)/Point;
   takeProfit = myATR * TakeProfitPercent/100.0;
   stopLoss = myATR * StopLossPercent/100.0;    
}

void updateBacktestResults()
{
   int total = OrdersHistoryTotal();
   for(int i = 0; i < total; i++){
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY) == false){
         Print("Access to history failed with error (",GetLastError(),")");
         break;
      }
      
      if(OrderType() == OP_BUY || OrderType() == OP_SELL){
         if((OrderProfit()+OrderSwap()+OrderCommission()) > 0){
            countTP++;
         }
         else {
            countSL++;
         }
      }
   }
   
   countTP = countTP - countWinsBeforeTP;
   countSL = countSL - countLossesBeforeSL;
}

double getNNFXWinrate(){
   double divisor = countTP + countSL + (countWinsBeforeTP + countLossesBeforeSL) / 2;
   return divisor == 0 ? 0 : NormalizeDouble((countTP + (countWinsBeforeTP / 2)) / divisor, 2);
}

double getLots(double StopInPips){
   double lot = 0.01;
   
   double TickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
   double divisor = (TickValue * StopInPips);
   if(divisor == 0.0){
      return lot;   
   }
   
   double LotStep = MarketInfo(_Symbol, MODE_LOTSTEP);
   int    Decimals = 0;
   if(LotStep == 0.1){
      Decimals = 1;
   }
   else if(LotStep == 0.01){
      Decimals = 2;
   }

   if(Point == 0.001 || Point == 0.00001){ 
      TickValue *= 10;
   }
   
   double AccountValue = AccountBalance();
   lot = (AccountValue * (RiskPercent/100)) / divisor;
   lot = StrToDouble(DoubleToStr(lot,Decimals));
   double myMaxLot = MarketInfo(_Symbol, MODE_MAXLOT);
   double myMinLot = MarketInfo(_Symbol, MODE_MINLOT);
   if (lot < myMinLot){ 
      lot = myMinLot;
   }
   if (lot > myMaxLot){ 
      lot = myMaxLot;
   }

   return lot;
}

void parseIndicatorParams(double &indParams[])
{
   int c = 0;
   ArrayInitialize(indParams, EMPTY_VALUE);
   if (IndicatorParam1 != PARAM_EMPTY){
      c = 1;
      indParams[0] = IndicatorParam1;
   }
   if (IndicatorParam2 != PARAM_EMPTY){
      c = 2;
      indParams[1] = IndicatorParam2;
   }
   if (IndicatorParam3 != PARAM_EMPTY){
      c = 3;
      indParams[2] = IndicatorParam3;
   }
   if (IndicatorParam4 != PARAM_EMPTY){
      c = 4;
      indParams[3] = IndicatorParam4;
   }  
   if (IndicatorParam5 != PARAM_EMPTY){
      c = 5;
      indParams[4] = IndicatorParam5;
   }
   if (IndicatorParam6 != PARAM_EMPTY){
      c = 6;
      indParams[5] = IndicatorParam6;
   }
   ArrayResize(indParams, c);
}

double iCustomArray(string symbol, int timeframe, string indicator, double &params[], int mode, int shift){
   int len = ArraySize(params);
   if(len == 0){
      return iCustom(symbol, timeframe, indicator, mode, shift);   
   }
   else if(len == 1){
      return iCustom(symbol, timeframe, indicator, params[0], mode, shift);   
   }
   else if(len == 2){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], mode, shift);   
   }
   else if(len == 3){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], mode, shift);   
   }
   else if(len == 4){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], mode, shift);   
   }
   else if(len == 5){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], mode, shift);   
   }
   else if(len == 6){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], mode, shift);   
   }
   else if(len == 7){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], mode, shift);   
   }
   else if(len == 8){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], mode, shift);   
   }
   else if(len == 9){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], mode, shift);   
   }
   else if(len == 10){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], mode, shift);   
   }
   else if(len == 11){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], params[10], mode, shift);   
   }
   else if(len >= 12){
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], params[10], params[11], mode, shift);   
   }
   return 0;
}
