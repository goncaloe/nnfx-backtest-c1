//+---------------------------------------------------------------------------|
//|                                                     NNFX_backtest_C1.mq4  |
//|                                                       by Gonçalo Esteves  |
//|                             https://github.com/goncaloe/nnfx-backtest-c1  |
//|                                                          August 17, 2019  |
//|                                                                    v1.12  |
//+---------------------------------------------------------------------------+
#property copyright "Copyright 2019, Gonçalo Esteves"
#property strict

#define SIDE_NONE 0
#define SIDE_LONG 1
#define SIDE_SHORT 2

enum IndicatorTypes {
   IND_2LineCross, //2Line Cross
   IND_ZeroLine, //ZeroLine Cross
   //IND_1LevelCross, //1Level Cross
   //IND_2LevelCross, //2Level Cross
   //IND_SingleLine, //Single Line
   IND_Histogram, //Histogram
};

enum OptimizationCalcTypes {
   WinrateSimple,
   WinrateEstimated,
   Takeprofit,
   Stoploss,
   WinsBeforeTP,
   LossesBeforeSL,
};

enum MMMethods {
   MM_Balance, //Balance
   MM_Equity, //Equity
   MM_FreeMargin, //Free Margin
   MM_Fixed, //Fixed
};

sinput int ATRPeriod = 14;
sinput int Slippage = 3;
static extern MMMethods MoneyManagementMethod = MM_Balance; //Money Management Method 
static extern double MoneyManagementLots = 0.1; //Money Management Lots
sinput double RiskPercent = 2;
sinput double TakeProfitPercent = 1.0;
sinput double StopLossPercent = 1.5;
sinput bool ReopenOnOppositeSignal = true;
sinput OptimizationCalcTypes OptimizationCalcType = 0;
sinput IndicatorTypes IndicatorType = 0; // C1 Type
sinput string IndicatorParams = "";  // C1 Parameters
extern double Input1 = 0; //Input #1
extern double Input2 = 0; //Input #2
extern double Input3 = 0; //Input #3
extern double Input4 = 0; //Input #4
extern double Input5 = 0; //Input #5
extern double Input6 = 0; //Input #6
extern double Input7 = 0; //Input #7
extern double Input8 = 0; //Input #8


// GLOBAL VARIABLES:
double myATR;
double stopLossATR;
double takeProfitATR;
int myTicket;
int myTrade;
int countTP = 0;
int countSL = 0;
int countWinsBeforeTP = 0;
int countLossesBeforeSL = 0;

string indPath;
int indIndexes[2];
double indValues[2];
double indDParams[];
string indSParams[];
uint indSBits;

int shift = 1;

int OnInit(void){
   if(!IsTesting()){
      MessageBox("This Expert Advisor can't run in Auto Trading mode");
      return INIT_FAILED; 
   }
   
   if(_Period != PERIOD_D1){
      Print("This Expert Advisor can't run in other periodd than D1");
      return INIT_FAILED;  
   }

   prepareParameters();

   if(StringLen(indPath) < 1){
      return INIT_PARAMETERS_INCORRECT;
   }
   
   string name = "ea_warn";
   ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetText(name, "Full Algorithm version coming soon");
   //ObjectSetText(name, "Full version visit mql5.com/en/market/product/12345");
   ObjectSet(name, OBJPROP_COLOR, SkyBlue);
   ObjectSet(name, OBJPROP_XDISTANCE, 10);
   ObjectSet(name, OBJPROP_YDISTANCE, 20);
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){
   updateBacktestResults();
   string text = StringConcatenate("WinsTP: ", countTP, "; LossesSL: ", countSL, "; WinsBeforeTP: ", countWinsBeforeTP, "; LossesBeforeSL: ", countLossesBeforeSL);
   StringAdd(text, StringFormat("; Winrate Simple: %.2f", getNNFXWinrate(true)));
   StringAdd(text, StringFormat("; Winrate Estimated: %.2f", getNNFXWinrate(false)));
   Print(text);
}

void OnTick(){
   datetime static lastTradeDay = 0;
   if(lastTradeDay == Time[0]){
      return;
   }
   lastTradeDay = Time[0];
   
   checkTicket();
   checkForOpen();
}

double OnTester()
{
   updateBacktestResults();
   switch(OptimizationCalcType){      
      case WinrateSimple:
         return getNNFXWinrate(true);
      case WinrateEstimated:
         return getNNFXWinrate(false); 
      case Takeprofit:
         return countTP;
      case Stoploss:
         return countSL;
      case WinsBeforeTP:
         return countWinsBeforeTP;
      case LossesBeforeSL:
         return countLossesBeforeSL;        
   }

   return 0;
}

//+-SIGNAL FUNCTIONS-------------------------------------------------+

/*
return int: the signal side of indicator
   SIDE_NONE: no sinal:
   SIDE_LONG: long signal
   SIDE_SHORT: short signal    
*/
int getSignal(){
   static int prevSide;
   static datetime prevDt = 0;

   if(prevDt != Time[1]){
      prevSide = EMPTY_VALUE; // invalidate prevSignal
   }
   prevDt = Time[0];

   //try get signal by Properties of Expert:
   int side = SIDE_NONE;
   switch(IndicatorType){
      case IND_2LineCross:
         side = get2LineCrossArraySide(indPath, indDParams, indSParams, indSBits, indIndexes[0], indIndexes[1], shift);
         break;
      case IND_ZeroLine:
         side = get1LevelCrossArraySide(indPath, indDParams, indSParams, indSBits, indIndexes[0], 0, shift);
         break;
      case IND_Histogram:
         side = getHistogramArraySide(indPath, indDParams, indSParams, indSBits, indIndexes[0], indIndexes[1], shift);
         break; 
   }

   // candle 0
   if(prevSide == EMPTY_VALUE){
      prevSide = side;
      return SIDE_NONE;
   }
   
   // signal change:
   if(side != SIDE_NONE && prevSide != side){
      prevSide = side;
      return side;
   }
   
   return SIDE_NONE;
}

int get2LineCrossArraySide(string path, double &dParams[], string &sParams[], uint sBits, int buff1, int buff2, int ishift){
   double v0 = MyCustom::iCustomArray(path, dParams, sParams, sBits, buff1, shift);
   double v1 = MyCustom::iCustomArray(path, dParams, sParams, sBits, buff2, shift);
   return v0 >= v1 ? SIDE_LONG : SIDE_SHORT;;
}

int get1LevelCrossArraySide(string path, double &dParams[], string &sParams[], uint sBits, int buff1, double level1, int ishift){
   double v = MyCustom::iCustomArray(path, dParams, sParams, sBits, buff1, shift); 
   return v >= level1 ? SIDE_LONG : SIDE_SHORT;
}


int getHistogramArraySide(string path, double &dParams[], string &sParams[], uint sBits, int buff1, int buff2, int ishift){
   double v0 = MyCustom::iCustomArray(path, dParams, sParams, sBits, buff1, shift);
   if(v0 != EMPTY_VALUE && v0 != 0){
      return SIDE_LONG;
   }
   double v1 = MyCustom::iCustomArray(path, dParams, sParams, sBits, buff2, shift);
   if(v1 != EMPTY_VALUE && v1 != 0){
      return SIDE_SHORT;
   }
   return SIDE_NONE;
}



//+-TRADE FUNCTIONS-------------------------------------------------+

void checkForOpen(){
   int signal = getSignal();
   
   if(!ReopenOnOppositeSignal && myTrade != SIDE_NONE){
      return;
   }
   
   if(signal == SIDE_NONE){
      return;
   }
   
   if(ReopenOnOppositeSignal && myTrade != SIDE_NONE && myTrade != signal){
      double close = myTrade == SIDE_LONG ? Bid : Ask;
      
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
      myTrade = SIDE_NONE;
   }
   
   if(myTrade != SIDE_NONE){
      return;
   }
   
   // calculate takeProfit and stopLoss
   updateValues();
   double myLots = getLotsBySL(stopLossATR);
   
   if(signal == SIDE_LONG){
      openTrade(OP_BUY, "Buy Order", myLots, stopLossATR, takeProfitATR);
   }
   else if(signal == SIDE_SHORT){
      openTrade(OP_SELL, "Sell Order", myLots, stopLossATR, takeProfitATR);
   }
   
}


void openTrade(int signal, string msg, double mLots, double mStopLoss, double mTakeProfit)
{  
   mLots = normalizeLots(mLots);
   double TPprice, STprice;
   if (signal == OP_BUY){
      TPprice = Ask + mTakeProfit * Point;
      STprice = Ask - mStopLoss * Point;
      if (Digits > 0)
      {
         STprice = NormalizeDouble(STprice, Digits);
         TPprice = NormalizeDouble(TPprice, Digits); 
      }
      myTicket = OrderSend(_Symbol,OP_BUY,mLots,Ask,Slippage,STprice,TPprice,msg,0,0,Green);
   }
   else if (signal == OP_SELL){
      TPprice = Bid - mTakeProfit * Point;
      STprice = Bid + mStopLoss * Point;
      if (Digits > 0) {
         STprice = NormalizeDouble(STprice, Digits);
         TPprice = NormalizeDouble(TPprice, Digits); 
      }
      myTicket = OrderSend(_Symbol,OP_SELL,mLots,Bid,Slippage,STprice,TPprice,msg,0,0,Red);
   }
}


// update myTicket and myTrade
void checkTicket(){
   myTicket = -1;
   myTrade = SIDE_NONE;
   if(OrdersTotal() >= 1){
      if(!OrderSelect(0, SELECT_BY_POS, MODE_TRADES)){
         return;   
      }
      int oType = OrderType();
      if(oType == OP_BUY){
         myTicket = OrderTicket();
         myTrade = SIDE_LONG;   
      }
      else if(oType == OP_SELL){
         myTicket = OrderTicket();
         myTrade = SIDE_SHORT;
      }
   }
}


//+-AUXILIAR FUNCTIONS----------------------------------------------+

void updateValues(){
   HideTestIndicators(true);
   myATR = iATR(NULL, 0, ATRPeriod, 1)/Point;
   HideTestIndicators(false);
   takeProfitATR = myATR * TakeProfitPercent;
   stopLossATR = myATR * StopLossPercent;    
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

double getNNFXWinrate(bool simple){
   double divisor;
   if(simple){
      divisor = countTP + countSL;
      return divisor == 0 ? 0 : countTP * 100 / divisor;
   }
   else {
      divisor = countTP + countSL + (countWinsBeforeTP + countLossesBeforeSL) / 2;
      return divisor == 0 ? 0 : (countTP + (countWinsBeforeTP / 2)) * 100 / divisor;
   }
}

double getLotsBySL(double stopLoss){
   double tickValue = MarketInfo(_Symbol, MODE_TICKVALUE);
   double minLot = MarketInfo(_Symbol, MODE_MINLOT);
   if(tickValue <= 0 || stopLoss <= 0){
      return minLot;   
   }

   double accountValue;
   switch (MoneyManagementMethod){
      case MM_Balance:
         accountValue = AccountBalance();
         break;   
      case MM_Equity: 
         accountValue = AccountEquity();
         break;
      case MM_FreeMargin:
         accountValue = AccountFreeMargin();
         break;
      default:
         accountValue = MoneyManagementLots;
   }
   
   double maxLot = MarketInfo(_Symbol, MODE_MAXLOT);
   double lots = (accountValue * RiskPercent * 0.01) / (tickValue * stopLoss);
   if (lots < minLot){ 
      lots = minLot;
   }
   else if (lots > maxLot){ 
      lots = maxLot;
   }
   
   return lots;
}

double normalizeLots(double lots){
   static int decimals = -1;
   if(decimals == -1){
      double lotStep = MarketInfo(_Symbol, MODE_LOTSTEP);
      decimals = 0;
      if(lotStep == 0.1){
         decimals = 1;
      }
      else if(lotStep == 0.01){
         decimals = 2;
      }
   }
   return NormalizeDouble(lots, decimals);
}

void prepareParameters(){
   int i, j, k;
   j = 12; // only consider first 12 parameters
   indPath = "";
   indIndexes[0] = 0;
   indIndexes[1] = 1;
   indValues[0] = 0;
   indValues[1] = 0;
   
   // p1,p2,p3; indicator_name; idx1,idx2; val1,val2
   string parts[];
   string parts2[];
   string sParam;
   ushort u_sep = StringGetCharacter(";", 0);
   ushort u_sep2 = StringGetCharacter(",", 0);
   StringSplit(IndicatorParams, u_sep, parts);
   int size = ArraySize(parts);
   int sCount = 0;
   if(size >= 1){
      StringSplit(parts[0], u_sep2, parts2);
      k = MathMin(ArraySize(parts2), j);
      ArrayResize(indDParams, k);
      ArrayResize(indSParams, k);
      i = 0;
      while(i < k){
         sParam = StringTrimLeft(StringTrimRight(parts2[i]));
         if(isInput(sParam)){
            parseInput(sParam, indDParams[i]);
         }
         else if(isNumeric(sParam)){
            parseDouble(sParam, indDParams[i]);
         }
         else {
            indSParams[i] = sParam;
            if(sCount++ < 2){
               indSBits |= (1 << (k - i - 1));
            }
         }
         i++;
      }
   }   
   if(size >= 2){
      indPath = parts[1];
   }
   if(size >= 3){
      StringSplit(parts[2], u_sep2, parts2);
      i = 0;
      k = MathMin(ArraySize(parts2), 2);
      while(i < k){
         indIndexes[i] = StrToInteger(parts2[i]);
         i++;
      }
   }
   if(size >= 4){
      StringSplit(parts[3], u_sep2, parts2);
      i = 0;
      k = MathMin(ArraySize(parts2), 2);
      while(i < k){
         indValues[i] = StrToDouble(parts2[i]);
         i++;
      }
   }
}


void parseDouble(string val, double &var, double def = 0){
   var = StrToDouble(val);
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

bool isInput(string text){
   int len = StringLen(text);
   if(len < 2 || StringGetChar(text, 0) != '#'){
      return false;
   }
   for(int i=1;i<len;i++){
      int ch = StringGetChar(text, i);
      if(ch <= 47 || ch >= 58){
         return false;
      }
   }
   return true;
}

bool isNumeric(string text){
   int length = StringLen(text);
   bool isN = false;
   int i = 0;
   if(StringGetChar(text, 0) == 45){
      i++;
   }
   for(;i<length;i++){
      int ch = StringGetChar(text, i);
      if(ch == 32 || ch == 46){
         continue;
      }
      else if(ch > 47 && ch < 58){
         isN = true;
      }
      else {
         return false;
      }
   }
   return isN;
}


class MyCustom {
   public:
   static double iCustomArray(string ind, double &dParams[], string &sParams[], uint sBits, int mode, int ishift){
      int size = ArraySize(dParams);
      switch(size){
         case 0:
            return iCustom(NULL, 0, ind, mode, ishift);
         case 1:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, sParams[0], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], mode, ishift);
            }
         case 2:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], mode, ishift);
               case 2:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], mode, ishift);
               case 3:
                  return iCustom(NULL, 0, ind, sParams[0], sParams[1], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], mode, ishift);
            }
         case 3:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], mode, ishift);
               case 2:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], mode, ishift);
               case 3:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], sParams[2], mode, ishift);
               case 4:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], mode, ishift);
               case 5:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], sParams[2], mode, ishift);
               case 6:
                  return iCustom(NULL, 0, ind, sParams[0], sParams[1], dParams[2], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], mode, ishift);
            }
         case 4:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], mode, ishift);
               case 2:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], mode, ishift);
               case 3:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], sParams[3], mode, ishift);
               case 4:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], mode, ishift);
               case 5:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], sParams[3], mode, ishift);
               case 6:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], sParams[2], dParams[3], mode, ishift);
               case 8:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], mode, ishift);
               case 9:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], sParams[3], mode, ishift);
               case 10:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], sParams[2], dParams[3], mode, ishift);
               case 12:
                  return iCustom(NULL, 0, ind, sParams[0], sParams[1], dParams[2], dParams[3], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], mode, ishift);
            }
         case 5:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], mode, ishift);
               case 2:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], mode, ishift);
               case 3:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], sParams[4], mode, ishift);
               case 4:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], mode, ishift);
               case 5:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], sParams[4], mode, ishift);
               case 6:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], sParams[3], dParams[4], mode, ishift);
               case 8:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], mode, ishift);
               case 9:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], sParams[4], mode, ishift);
               case 10:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], sParams[3], dParams[4], mode, ishift);
               case 12:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], sParams[2], dParams[3], dParams[4], mode, ishift);
               case 16:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], mode, ishift);
               case 17:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], sParams[4], mode, ishift);
               case 18:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], sParams[3], dParams[4], mode, ishift);
               case 20:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], sParams[2], dParams[3], dParams[4], mode, ishift);
               case 24:
                  return iCustom(NULL, 0, ind, sParams[0], sParams[1], dParams[2], dParams[3], dParams[4], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], mode, ishift);
            }
         case 6:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], mode, ishift);
               case 2:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], mode, ishift);
               case 3:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], sParams[5], mode, ishift);
               case 4:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], mode, ishift);
               case 5:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], sParams[5], mode, ishift);
               case 6:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], sParams[4], dParams[5], mode, ishift);
               case 8:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], mode, ishift);
               case 9:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], sParams[5], mode, ishift);
               case 10:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], sParams[4], dParams[5], mode, ishift);
               case 12:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], sParams[3], dParams[4], dParams[5], mode, ishift);
               case 16:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], mode, ishift);
               case 17:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], sParams[5], mode, ishift);
               case 18:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], sParams[4], dParams[5], mode, ishift);
               case 20:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], sParams[3], dParams[4], dParams[5], mode, ishift);
               case 24:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], sParams[2], dParams[3], dParams[4], dParams[5], mode, ishift);
               case 32:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], mode, ishift);
               case 33:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], mode, ishift);
               case 34:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], mode, ishift);
               case 36:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], mode, ishift);
               case 40:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], mode, ishift);
               case 48:
                  return iCustom(NULL, 0, ind, sParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], mode, ishift);
            }
         case 7:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], sParams[6], mode, ishift);
               case 2:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], dParams[6], mode, ishift);
               case 3:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], sParams[6], mode, ishift);
               case 4:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], dParams[6], mode, ishift);
               case 5:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], sParams[6], mode, ishift);
               case 6:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], sParams[5], dParams[6], mode, ishift);
               case 8:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
               case 9:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], sParams[6], mode, ishift);
               case 10:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], sParams[5], dParams[6], mode, ishift);
               case 12:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], sParams[4], dParams[5], dParams[6], mode, ishift);
               case 16:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
               case 17:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], sParams[6], mode, ishift);
               case 18:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], sParams[5], dParams[6], mode, ishift);
               case 20:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], sParams[4], dParams[5], dParams[6], mode, ishift);
               case 24:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], sParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
               case 32:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
               case 33:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], sParams[6], mode, ishift);
               case 34:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], sParams[5], dParams[6], mode, ishift);
               case 36:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], sParams[4], dParams[5], dParams[6], mode, ishift);
               case 40:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], sParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
               case 48:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], sParams[2], dParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
               case 64:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
               case 65:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], sParams[6], mode, ishift);
               case 66:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], dParams[6], mode, ishift);
               case 68:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], dParams[6], mode, ishift);
               case 72:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
               case 80:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
               case 96:
                  return iCustom(NULL, 0, ind, sParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], mode, ishift);
            }
         case 8:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], sParams[7], mode, ishift);
               case 2:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], sParams[6], dParams[7], mode, ishift);
               case 3:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], sParams[6], sParams[7], mode, ishift);
               case 4:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], dParams[6], dParams[7], mode, ishift);
               case 5:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], dParams[6], sParams[7], mode, ishift);
               case 6:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], sParams[6], dParams[7], mode, ishift);
               case 8:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 9:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], dParams[6], sParams[7], mode, ishift);
               case 10:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], sParams[6], dParams[7], mode, ishift);
               case 12:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], sParams[5], dParams[6], dParams[7], mode, ishift);
               case 16:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 17:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], dParams[6], sParams[7], mode, ishift);
               case 18:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], sParams[6], dParams[7], mode, ishift);
               case 20:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], sParams[5], dParams[6], dParams[7], mode, ishift);
               case 24:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], sParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 32:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 33:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], dParams[6], sParams[7], mode, ishift);
               case 34:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], sParams[6], dParams[7], mode, ishift);
               case 36:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], sParams[5], dParams[6], dParams[7], mode, ishift);
               case 40:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], sParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 48:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], sParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 64:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 65:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], sParams[7], mode, ishift);
               case 66:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], sParams[6], dParams[7], mode, ishift);
               case 68:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], sParams[5], dParams[6], dParams[7], mode, ishift);
               case 72:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], sParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 80:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], sParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 96:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], sParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 128:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 129:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], sParams[7], mode, ishift);
               case 130:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], sParams[6], dParams[7], mode, ishift);
               case 132:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], dParams[6], dParams[7], mode, ishift);
               case 136:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 144:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 160:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               case 192:
                  return iCustom(NULL, 0, ind, sParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], mode, ishift);
            }
         case 9:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], sParams[8], mode, ishift);
               case 2:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], sParams[7], dParams[8], mode, ishift);
               case 4:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], sParams[6], dParams[7], dParams[8], mode, ishift);
               case 8:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], dParams[6], dParams[7], dParams[8], mode, ishift);
               case 16:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], dParams[6], dParams[7], dParams[8], mode, ishift);
               case 32:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], mode, ishift);
               case 64:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], mode, ishift);
               case 128:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], mode, ishift);
               case 256:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], mode, ishift);
            }
         case 10:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], sParams[9], mode, ishift);
               case 2:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], sParams[8], dParams[9], mode, ishift);
               case 4:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], sParams[7], dParams[8], dParams[9], mode, ishift);
               case 8:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], sParams[6], dParams[7], dParams[8], dParams[9], mode, ishift);
               case 16:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], dParams[6], dParams[7], dParams[8], dParams[9], mode, ishift);
               case 32:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], mode, ishift);
               case 64:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], mode, ishift);
               case 128:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], mode, ishift);
               case 256:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], mode, ishift);
               case 512:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], mode, ishift);
            }
         case 11:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], sParams[10], mode, ishift);
               case 2:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], sParams[9], dParams[10], mode, ishift);
               case 4:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], sParams[8], dParams[9], dParams[10], mode, ishift);
               case 8:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], sParams[7], dParams[8], dParams[9], dParams[10], mode, ishift);
               case 16:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], sParams[6], dParams[7], dParams[8], dParams[9], dParams[10], mode, ishift);
               case 32:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], mode, ishift);
               case 64:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], mode, ishift);
               case 128:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], mode, ishift);
               case 256:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], mode, ishift);
               case 512:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], mode, ishift);
               case 1024:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], mode, ishift);
            }
         case 12:
            switch(sBits){
               case 0:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], dParams[11], mode, ishift);
               case 1:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], sParams[11], mode, ishift);
               case 2:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], sParams[10], dParams[11], mode, ishift);
               case 4:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], sParams[9], dParams[10], dParams[11], mode, ishift);
               case 8:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], sParams[8], dParams[9], dParams[10], dParams[11], mode, ishift);
               case 16:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], sParams[7], dParams[8], dParams[9], dParams[10], dParams[11], mode, ishift);
               case 32:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], sParams[6], dParams[7], dParams[8], dParams[9], dParams[10], dParams[11], mode, ishift);
               case 64:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], sParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], dParams[11], mode, ishift);
               case 128:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], sParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], dParams[11], mode, ishift);
               case 256:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], sParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], dParams[11], mode, ishift);
               case 512:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], sParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], dParams[11], mode, ishift);
               case 1024:
                  return iCustom(NULL, 0, ind, dParams[0], sParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], dParams[11], mode, ishift);
               case 2048:
                  return iCustom(NULL, 0, ind, sParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], dParams[11], mode, ishift);
               default:
                  return iCustom(NULL, 0, ind, dParams[0], dParams[1], dParams[2], dParams[3], dParams[4], dParams[5], dParams[6], dParams[7], dParams[8], dParams[9], dParams[10], dParams[11], mode, ishift);
            }
      }
      return EMPTY_VALUE;
   }
};
