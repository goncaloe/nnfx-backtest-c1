//+---------------------------------------------------------------------------|
//|                                                        NNFX_backtest.mq4  |
//|                                                       by Gonçalo Esteves  |
//|                                                          August 17, 2019  |
//|                                                                     v1.2  |
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2019, Gonçalo Esteves"
#property strict

extern int MagicNumber = 265258;
extern int ATRPeriod = 14;
extern int TakeProfitPercent = 100;
extern int StopLossPercent = 150;
extern int Slippage = 3;
extern int MoneyManagementMethod = 1;
extern double RiskPercent = 2;
extern double MoneyManagementLots = 0.1;

// GLOBAL VARIABLES:
double myLots;
double myATR;
double stopLoss;
double takeProfit;
int myTicket = -1;

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+

void init() {

    //setup = "NNFX Indicator " + Symbol() + "_Daily";
}


void OnTick()
{
   
   checkTicket();
   
   checkForOpen();
  
}
//+------------------------------------------------------------------+

void checkForOpen(){
   // salta se não foi o 1º tick do candle 
   if(Volume[0]>1) return;
   
   if(myTicket > 0) return; 

   updateValues();

   int signal = getSignal();
   
   if(signal == OP_BUY){
      myLots = getLots(stopLoss);
      myTicket = openTrade(OP_BUY, "Buy Order", myLots, stopLoss, takeProfit);
   }
   else if(signal == OP_SELL){
      myLots = getLots(stopLoss);
      myTicket = openTrade(OP_SELL, "Sell Order", myLots, stopLoss, takeProfit);
   }
}


void checkTicket(){
   myTicket = -1;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES) == false) break;
      
      if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
      {
         if(OrderType() == OP_BUY){
            myTicket = OrderTicket();   
         }
         else if(OrderType() == OP_SELL){
            myTicket = OrderTicket();
         }
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

int openTrade(int signal, string msg, double mLots, double mStopLoss, double mTakeProfit)
{  
   int ticket = -1;
   double TPprice, STprice;
  
   //RefreshRates();
   
   if (signal==OP_BUY) 
   {
      ticket=OrderSend(Symbol(),OP_BUY,mLots,Ask,Slippage,0,0,msg,MagicNumber,0,Green);
      if (ticket > 0)
      {
         if (OrderSelect( ticket,SELECT_BY_TICKET, MODE_TRADES) ) 
         {
            TPprice = Ask + mTakeProfit*Point;
            STprice = Ask - mStopLoss*Point;
            // Normalize stoploss / takeprofit to the proper # of digits.
            if (Digits > 0)
            {
              STprice = NormalizeDouble( STprice, Digits);
              TPprice = NormalizeDouble( TPprice, Digits); 
            }
		      if(!OrderModify(ticket, OrderOpenPrice(), STprice, TPprice,0, LightGreen)){
               Print("OrderModify error ",GetLastError());
               return(-1);
		      }
		   }
         
      }
   }
   else if (signal==OP_SELL) 
   {
      ticket=OrderSend(Symbol(),OP_SELL,mLots,Bid,Slippage,0,0,msg,MagicNumber,0,Red);
      if (ticket > 0)
      {
         if (OrderSelect( ticket,SELECT_BY_TICKET, MODE_TRADES) ) 
         {
            TPprice=Bid - mTakeProfit*Point;
            STprice = Bid + mStopLoss*Point;
            // Normalize stoploss / takeprofit to the proper # of digits.
            if (Digits > 0) 
            {
              STprice = NormalizeDouble( STprice, Digits);
              TPprice = NormalizeDouble( TPprice, Digits); 
            }
		      
		      if(!OrderModify(ticket, OrderOpenPrice(), STprice, TPprice,0, LightGreen)){
               Print("OrderModify error ",GetLastError());
               return(-1);
		      }
         }
       }
   }
   return(ticket);
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
   //int result = getMASignal("TEMA", 25);
   
   //Crossover:
   //double indParams[] = {14};
   //int result = getIndicatorCrossoverSignal("Vortex", indParams, 0, 1);
   double indParams[] = {25};
   int result = getIndicatorCrossoverSignal("SSL", indParams, 1, 0);
   //double indParams[] = {0,7,3,4,3};
   //int result = getIndicatorCrossoverSignal("Absolute_Strength_Histogram", indParams, 2, 3);
   
   //Others:
   //int result = getDidiSignal();
   //double indParams[] = {15, 120, 240};
   //int result = getChaffSignal(indParams);

   return(result);
}


int getIndicatorCrossoverSignal(string ind, double &params[], int buff1, int buff2)
{
   double v0Curr = iCustomArray(NULL, 0, ind, params, buff1, 1);
   double v0Prev = iCustomArray(NULL, 0, ind, params, buff1, 2);
   double v1Curr = iCustomArray(NULL, 0, ind, params, buff2, 1);
   double v1Prev = iCustomArray(NULL, 0, ind, params, buff2, 2);  
   int signal = -1;
   if(v0Prev < v1Prev && v0Curr > v1Curr){
      signal = OP_BUY;
   }
   else if(v0Prev > v1Prev && v0Curr < v1Curr){
      signal = OP_SELL;
   }
   return(signal);
}


int getMASignal(string ind, int period)
{
   double vCurr = iCustom(NULL, 0, ind, period, 0, 1);
   double vPrev = iCustom(NULL, 0, ind, period, 0, 2);
   double vPrev2 = iCustom(NULL, 0, ind, period, 0, 3);
   
   int signal = -1;
   if(vCurr > vPrev && vPrev2 >= vPrev){
      signal = OP_BUY;
   }
   else if(vCurr < vPrev && vPrev2 <= vPrev){
      signal = OP_SELL;
   }
   return(signal);
}


int getChaffSignal(double &params[])
{
   string ind = "Schaff_Trend_Cycle";
   //double vCurr = iCustom(NULL, 0, ind, 15, 120, 240, 0, 1);
   //double vPrev = iCustom(NULL, 0, ind, 15, 120, 240, 0, 2);

   double vCurr = iCustomArray(NULL, 0, ind, params, 0, 1);
   double vPrev = iCustomArray(NULL, 0, ind, params, 0, 2);
   
   int signal = -1;
   
   if(vPrev < 10 && vCurr > 10){
      signal = OP_BUY;
   }
   else if(vPrev > 90 && vCurr < 90){
      signal = OP_SELL;
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
   
   int signal = -1;
   bool isCross = (greenPrev < blue && greenCurr > blue) || (redPrev > blue && redCurr < blue);
   if(isCross && redCurr < blue){
      signal = OP_BUY;
   }
   else if(isCross && greenCurr < blue){
      signal = OP_SELL;
   }
   return(signal);
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
   return(0);
}

