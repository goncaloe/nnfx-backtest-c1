//+---------------------------------------------------------------------------|
//|                                                        NNFX_backtest.mq4  |
//|                                                       by Gonçalo Esteves  |
//|                                https://github.com/goncaloe/nnfx-backtest  |
//|                                                          August 17, 2019  |
//|                                                                     v1.9  |
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2019, Gonçalo Esteves"
#property strict

#define FLAT 0
#define LONG 1
#define SHORT 2
#define INPUT_EMPTY 999.0

enum IndicatorTypes {
   ________GENERIC_______ = 0,
   ZeroLine = 1,
   Crossover = 2,
   MovingAvarage = 3,
   ________CROSSOVER_____ = 4,
   Absolute_Strength_Histogram = 5,
   Vortex = 6,
   RVI = 7,
   Aroon_Horn = 8,
   ASO = 9,
   SSL = 10,
   ________ZEROLINE______ = 11,
   Accelerator_LSMA = 12,
   TSI = 13,
   ________OTHER_________ = 14,
   Schaff_Trend_Cycle = 15,      
   ________VOLUME________ = 16,   
   Waddah_Attar_Explosion = 17,
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
sinput string IndicatorPath = "MyIndicator";
sinput IndicatorTypes IndicatorType = 1;
sinput string IndicatorParams = "";
sinput int IndicatorIndex1 = 0;
sinput int IndicatorIndex2 = 1;
extern double Input1 = INPUT_EMPTY;
extern double Input2 = INPUT_EMPTY;
extern double Input3 = INPUT_EMPTY;
extern double Input4 = INPUT_EMPTY;
extern double Input5 = INPUT_EMPTY;
extern double Input6 = INPUT_EMPTY;
extern double Input7 = INPUT_EMPTY;
extern double Input8 = INPUT_EMPTY;


// GLOBAL VARIABLES:
double myATR;
double stopLoss;
double takeProfit;
int myTicket;
int myTrade;
string myParams[];
int countTP = 0;
int countSL = 0;
int countWinsBeforeTP = 0;
int countLossesBeforeSL = 0;

int OnInit(void){
   prepareParameters(IndicatorParams, myParams);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){  
   updateBacktestResults();
   string text = StringConcatenate("WinsTP: ", countTP, "; LossesSL: ", countSL, "; WinsBeforeTP: ", countWinsBeforeTP, "; LossesBeforeSL: ", countLossesBeforeSL);
   StringAdd(text, StringFormat("; Winrate: %.2f", getNNFXWinrate()));
   Print(text);
}

void OnTick(){  
   checkTicket();
   checkForOpen();
}

double OnTester()
{
   updateBacktestResults();
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

   //to test combo indicators, uncomment these 5 lines:
   //double c1Params[] = {0,9,5,4,3};
   //int c1 = getIndicatorCrossoverSignal("Absolute_Strength_Histogram", c1Params, 2, 3);   
   //double c2Params[] = {5,8};
   //int c2 = getIndicatorZerocrossSignal("TSI", c2Params, 0);
   //return comboSignal(c1, c2);



   //try get signal by Properties of Expert:
   int signal = FLAT;
   double indParams[];
   switch(IndicatorType){
      case 1:
         parseParametersDouble(myParams, indParams);
         signal = getIndicatorZerocrossSignal(IndicatorPath, indParams, IndicatorIndex1);
         break;
      case 2:
         parseParametersDouble(myParams, indParams);
         signal = getIndicatorCrossoverSignal(IndicatorPath, indParams, IndicatorIndex1, IndicatorIndex2);
         break;
      case 3:
         parseParametersDouble(myParams, indParams);
         signal = getIndicatorMASignal(IndicatorPath, indParams, IndicatorIndex1);
         break;
      case 5:
         signal = getAbsoluteStrengthHistogramSignal();
         break;
      case 6:
         signal = getVortexSignal();    
         break;         
      case 7:
         signal = getRVISignal();
         break;
      case 8:
         signal = getAroonHornSignal();
         break;
      case 9:
         signal = getASOSignal();
         break;
      case 10:
         signal = getSSLSignal();
         break;
      case 12:
         signal = getAcceleratorLSMASignal();    
         break;
      case 13:
         signal = getTSISignal();    
         break;
      case 15:
         signal = getSchaffTrendCycleSignal();
         break;
      case 17:
         signal = getWaddahAttarExplosionSignal();
         break;                     
   }
      
   return simpleSignal(signal);
}

// returns a new signal only when signal differ of previous
int simpleSignal(int signal){
   static int prevSignal = FLAT;
   if(signal == FLAT){
      return FLAT;
   }
   
   if(prevSignal == FLAT){
      prevSignal = signal;
      return FLAT;
   }
   else if(prevSignal != signal){
      prevSignal = signal;
      return signal;
   }
   return FLAT;
}

// returns a new signal only when signal differ of previous and c2 agrees
int comboSignal(int c1Signal, int c2Signal){
   static int prevSignal = FLAT;
   if(c1Signal == FLAT){
      return FLAT;
   }
   
   if(prevSignal == FLAT){
      prevSignal = c1Signal;
      return FLAT;
   }
   else if(prevSignal != c1Signal && (myTrade == prevSignal || c1Signal == c2Signal)){
      prevSignal = c1Signal;
      return c1Signal;
   }
   return FLAT;
}

int getIndicatorCrossoverSignal(string ind, double &params[], int buff1, int buff2)
{
   double v0Curr = iCustomArray(NULL, 0, ind, params, buff1, 1);
   double v1Curr = iCustomArray(NULL, 0, ind, params, buff2, 1);
   int signal = FLAT;
   if(v0Curr > v1Curr){
      signal = LONG;
   }
   else if(v0Curr < v1Curr){
      signal = SHORT;
   }
   return signal;
}

int getIndicatorZerocrossSignal(string ind, double &params[], int buff)
{
   double vCurr = iCustomArray(NULL, 0, ind, params, buff, 1);  
   int signal = FLAT;
   if(vCurr >= 0){
      signal = LONG;
   }
   else if(vCurr <= 0){
      signal = SHORT;
   }
   return signal;
}

int getIndicatorMASignal(string ind, double &params[], int buff)
{
   double vCurr = iCustom(NULL, 0, ind, params[0], buff, 1);
   double vPrev = iCustom(NULL, 0, ind, params[0], buff, 2);
   
   int signal = FLAT;
   if(vCurr > vPrev){
      signal = LONG;
   }
   else if(vCurr < vPrev){
      signal = SHORT;
   }
   return signal;
}

int getAbsoluteStrengthHistogramSignal(){
   double indParams[];
   parseParametersDouble(myParams, indParams, 7);
   return getIndicatorCrossoverSignal(IndicatorPath, indParams, 2, 3);
}

int getAcceleratorLSMASignal(){
   double indParams[];
   parseParametersDouble(myParams, indParams, 3);
   return getIndicatorZerocrossSignal(IndicatorPath, indParams, 0);
}

int getVortexSignal(){
   double indParams[];
   parseParametersDouble(myParams, indParams, 1);
   return getIndicatorCrossoverSignal(IndicatorPath, indParams, 0, 1);
}

int getSchaffTrendCycleSignal(){
   double indParams[];
   parseParametersDouble(myParams, indParams, 3);
   
   double vCurr = iCustomArray(NULL, 0, IndicatorPath, indParams, 0, 1);
   double vPrev = iCustomArray(NULL, 0, IndicatorPath, indParams, 0, 2);
   
   int signal = FLAT;
   
   if(vPrev < 10 && vCurr > 10){
      signal = LONG;
   }
   else if(vPrev > 90 && vCurr < 90){
      signal = SHORT;
   }
   
   return(signal);
}

int getTSISignal(){
   double indParams[];
   parseParametersDouble(myParams, indParams, 2);
   return getIndicatorZerocrossSignal(IndicatorPath, indParams, 0);
}

int getASOSignal(){
   double param1 = 10;
   double param2 = 0;
   bool param3 = true;
   bool param4 = true;
   
   int len = ArraySize(myParams);
   if(len >= 1){
      parseDouble(myParams[0], param1);
   }
   if(len >= 2){
      parseDouble(myParams[1], param2);
   }
   if(len >= 3){
      parseBool(myParams[2], param3);
   }
   if(len >= 4){
      parseBool(myParams[3], param4);
   }
   
   double vCurr = iCustom(NULL, 0, IndicatorPath, param1, param2, param3, param4, 0, 1);
   if(vCurr >= 50){
      return LONG;
   }
   else {
      return SHORT;
   }
}


int getDidiSignal()
{
   string ind = "Didi_Index";
   // rules: https://www.forexfactory.com/showthread.php?t=512503   
   
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

int getSSLSignal(){
   double indParams[];
   parseParametersDouble(myParams, indParams, 1);
   return getIndicatorCrossoverSignal(IndicatorPath, indParams, 1, 0);
}

int getRVISignal(){
   double indParams[];
   parseParametersDouble(myParams, indParams, 1);
   return getIndicatorCrossoverSignal(IndicatorPath, indParams, 0, 1);
}

int getAroonHornSignal(){
   double indParams[];
   parseParametersDouble(myParams, indParams, 1);
   return getIndicatorCrossoverSignal(IndicatorPath, indParams, 0, 1);
}


int getWaddahAttarExplosionSignal(){
   double indParams[];
   parseParametersDouble(myParams, indParams, 4);
   double green = iCustomArray(NULL, 0, IndicatorPath, indParams, 0, 1);
   double red = iCustomArray(NULL, 0, IndicatorPath, indParams, 1, 1);
   double ma = iCustomArray(NULL, 0, IndicatorPath, indParams, 2, 1);
   if(green > ma){
      return LONG;
   }
   else if(red > ma){
      return SHORT;
   }
   return FLAT;
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
   countTP = 0;
   countSL = 0;
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
   return divisor == 0 ? 0 : NormalizeDouble((countTP + (countWinsBeforeTP / 2)) * 100 / divisor, 2);
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

void prepareParameters(const string params, string &parts[]){
   ushort u_sep = StringGetCharacter(",", 0);
   StringSplit(IndicatorParams, u_sep, parts);
}

void parseParametersDouble(string &params[], double &indParams[], int maxsize = NULL){
   int k = ArraySize(myParams);
   if(maxsize != NULL && maxsize < k){
      k = maxsize;
   }
   ArrayResize(indParams, k);
   for(int i = 0; i < k; i++){
      parseDouble(myParams[i], indParams[i]);   
   }
}

void parseDouble(string val, double &var, double def = 0){
   if(StringGetChar(val, 0) == '#' && StringGetChar(val, 1) >= '1' && StringGetChar(val, 1) <= '8'){
      parseInput(val, var);
      return;
   }
   var = StrToDouble(val);
}

void parseColor(string val, color &var, color def = 0){
   var = StringToColor(val);
}

void parseBool(string val, bool &var, bool def = false){
   if(val == "1" || val == "true"){
      var = true;   
   }
   else if(val == "0" || val == "false"){
      var = false;
   }
   else {
      var = def;
   }
}

void parseInput(string val, double &var){
   int idx = StrToInteger(StringSubstr(val, 1, 1));
   switch(idx){
      case 1:
         var = Input1;
         break;
      case 2:
         var = Input2;
         break;
      case 3:
         var = Input3;
         break;
      case 4:
         var = Input4;
         break;
      case 5:
         var = Input5;
         break;
      case 6:
         var = Input6;
         break;
      case 7:
         var = Input7;
         break;
      case 8:
         var = Input8;
         break;                                     
   }
}