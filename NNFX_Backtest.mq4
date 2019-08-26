//+---------------------------------------------------------------------------|
//|                                                        NNFX_backtest.mq4  |
//|                                                       by Gonçalo Esteves  |
//|                                                          August 17, 2019  |
//|                                                                     v1.5  |
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2019, Gonçalo Esteves"
#property strict

#define FLAT 0
#define LONG 1
#define SHORT 2

extern int MagicNumber = 265258;
extern int ATRPeriod = 14;
extern int TakeProfitPercent = 100;
extern int StopLossPercent = 150;
extern int Slippage = 3;
extern int MoneyManagementMethod = 1;
extern double RiskPercent = 2;
extern double MoneyManagementLots = 0.1;
extern bool ReopenOnOppositeSignal = true;

// GLOBAL VARIABLES:
double myLots;
double myATR;
double stopLoss;
double takeProfit;
int myTicket;
int myTrade;

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

void OnTick()
{  
   checkTicket();
   
   checkForOpen();
}
//+------------------------------------------------------------------+

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
      if(!OrderClose(myTicket, OrderLots(), close, Slippage)){
         return;
      }
      myTicket = -1;
      myTrade = FLAT;
   }
   
   if(myTrade != FLAT){
      return;
   }
   
   // calculate takeProfit and stopLoss
   updateValues();
   myLots = getLots(stopLoss);
   
   if(signal == LONG){
      openTrade(OP_BUY, "Buy Order", myLots, stopLoss, takeProfit);
   }
   else if(signal == SHORT){
      openTrade(OP_SELL, "Sell Order", myLots, stopLoss, takeProfit);
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

void updateValues(){
   myATR = iATR(NULL, 0, ATRPeriod, 1)/Point;
   takeProfit = myATR * TakeProfitPercent/100.0;
   stopLoss = myATR * StopLossPercent/100.0;    
}

double getLots(double StopInPips)
{
   int    Decimals = 0;
   double lot, AccountValue;
   double myMaxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double myMinLot = MarketInfo(Symbol(), MODE_MINLOT);
   
   double LotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   double LotSize = MarketInfo(Symbol(), MODE_LOTSIZE);
   double TickValue = MarketInfo(Symbol(), MODE_TICKVALUE);

   if(LotStep == 0.1){
      Decimals = 1;
   }
   else if(LotStep == 0.01){
      Decimals = 2;
   }
   
   switch (MoneyManagementMethod)
   {
      case 1: 
         AccountValue = AccountEquity();
         break;
      case 2:
         AccountValue = AccountFreeMargin();
         break;
      case 3:
         AccountValue = AccountBalance();
         break; 
      default:
         return(MoneyManagementLots);
   }
   
   if(Point == 0.001 || Point == 0.00001){ 
      TickValue *= 10;
   }

   lot = (AccountValue * (RiskPercent/100)) / (TickValue * StopInPips);
   lot = StrToDouble(DoubleToStr(lot,Decimals));
   if (lot < myMinLot){ 
      lot = myMinLot;
   }
   if (lot > myMaxLot){ 
      lot = myMaxLot;
   }

   return(lot);
}

void openTrade(int signal, string msg, double mLots, double mStopLoss, double mTakeProfit)
{  
   double TPprice, STprice;
  
   //RefreshRates();
   
   if (signal==OP_BUY) 
   {
      myTicket = OrderSend(Symbol(),OP_BUY,mLots,Ask,Slippage,0,0,msg,MagicNumber,0,Green);
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
      myTicket = OrderSend(Symbol(),OP_SELL,mLots,Bid,Slippage,0,0,msg,MagicNumber,0,Red);
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


/*
   return int: the signal of indicator
      -1: no sinal:
      OP_BUY: long signal
      OP_SELL: short signal
   uncomment only the indicator that we are testing    
*/
int getSignal()
{
   //MA:
   //int signal = getIndicatorMASignal("TEMA", 25, 0);
   
   //Zerocross:
   //double indParams[] = {20};
   //int signal = getIndicatorZerocrossSignal("CMF", indParams, 0);
   
   //Crossover:
   //double indParams[] = {14};
   //int signal = getIndicatorCrossoverSignal("Vortex", indParams, 0, 1);
   double indParams[] = {25};
   int signal = getIndicatorCrossoverSignal("SSL", indParams, 1, 0);
   //double indParams[] = {1,7,1,4,3};
   //int signal = getIndicatorCrossoverSignal("Absolute_Strength_Histogram", indParams, 2, 3);
   //double indParams[] = {14};
   //int signal = getIndicatorCrossoverSignal("RVI", indParams, 0, 1);
   //double indParams[] = {14};
   //int signal = getIndicatorCrossoverSignal("Aroon_Horn", indParams, 0, 1);
   
   //Others:
   //int result = getDidiSignal();
   //double indParams[] = {15, 120, 240};
   //int signal = getChaffSignal(indParams);

   return(signal);
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
   return(signal);
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
   return(signal);
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
   return(signal);
}

// alias
int getIndicatorMASignal(string ind, double period, int buff)
{
   double indParams[] = {0};
   indParams[0] = period;
   return(getIndicatorMASignal(ind, indParams, buff));
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
      return iCustom(symbol, timeframe, indicator, params[0], params[1], params[2], params[3], params[4], params[5], params[6], params[7], params[8], params[9], params[11], mode, shift);   
   }
   return 0;
}

// other specific indicators:
int getChaffSignal(double &params[])
{
   string ind = "Schaff_Trend_Cycle";
   //double vCurr = iCustom(NULL, 0, ind, 15, 120, 240, 0, 1);
   //double vPrev = iCustom(NULL, 0, ind, 15, 120, 240, 0, 2);

   double vCurr = iCustomArray(NULL, 0, ind, params, 0, 1);
   double vPrev = iCustomArray(NULL, 0, ind, params, 0, 2);
   
   int signal = FLAT;
   
   if(vPrev < 10 && vCurr > 10){
      signal = LONG;
   }
   else if(vPrev > 90 && vCurr < 90){
      signal = SHORT;
   }
   
   return(signal);
}

int getDidiSignal()
{
   string ind = "Didi_Index";
   // regras: https://www.forexfactory.com/showthread.php?t=512503   
   
   double greenCurr = iCustom(NULL, 0, ind, 0, 1);
   double greenPrev = iCustom(NULL, 0, ind, 0, 2);
   double blue = 1.0;
   double redCurr = iCustom(NULL, 0, ind, 2, 1);
   double redPrev = iCustom(NULL, 0, ind, 2, 2);
   
   int signal = FLAT;
   bool isCross = (greenPrev < blue && greenCurr > blue) || (redPrev > blue && redCurr < blue);
   if(isCross && redCurr < blue){
      signal = LONG;
   }
   else if(isCross && greenCurr < blue){
      signal = SHORT;
   }
   return(signal);
}
