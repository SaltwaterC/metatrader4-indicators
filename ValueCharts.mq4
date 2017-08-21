//+------------------------------------------------------------------+
//|                                                  ValueCharts.mq4 |
//|                                                      Stefan Rusu |
//|                                             saltwaterc@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Stefan Rusu"
#property link      "saltwaterc@gmail.com"
#property version   "1.00"
#property strict

#property indicator_separate_window
#property indicator_buffers 5

#property indicator_levelcolor Gray
#property indicator_levelstyle 0
#property indicator_level1 10
#property indicator_level2 8
#property indicator_level3 -8
#property indicator_level4 -10
#property indicator_maximum 12
#property indicator_minimum -12

//--- constants
#define NAME "ValueCharts"
#define STATE_OVERBOUGHT 1
#define STATE_NEUTRAL 0
#define STATE_OVERSOLD -1

//--- buffers
double VC_Open[];
double VC_High[];
double VC_Low[];
double VC_Close[];
double VC_Notify[];

//--- input parameters
input int VC_Period=5;
input bool VC_Embed=false;
input color VC_Bull_Candle=Lime;
input color VC_Bear_Candle=Red;
input bool VC_Signal=true;
input double VC_Signal_Limit=8;
input bool VC_Notify_Alert=true;
input bool VC_Notify_Push=true;
input bool VC_Notify_Email=false;
input string VC_Buy_Message="BUY";
input string VC_Sell_Message="SELL";

//--- global variables
string IndicatorName=NAME+"("+(string)VC_Period+")";
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
   IndicatorShortName(IndicatorName);

   SetIndexStyle(0,DRAW_NONE);
   SetIndexLabel(0,"Open");
   SetIndexBuffer(0,VC_Open);

   SetIndexStyle(1,DRAW_NONE);
   SetIndexLabel(1,"High");
   SetIndexBuffer(1,VC_High);

   SetIndexStyle(2,DRAW_NONE);
   SetIndexLabel(2,"Low");
   SetIndexBuffer(2,VC_Low);

   SetIndexStyle(3,DRAW_NONE);
   SetIndexLabel(3,"Close");
   SetIndexBuffer(3,VC_Close);
   
   SetIndexStyle(4,DRAW_NONE);
   SetIndexLabel(4,NULL);
   SetIndexBuffer(4,VC_Notify);

   return 0;
  }
//+------------------------------------------------------------------+
//| Custom deinitialisation function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
   ObjectsDeleteAll(window());
   return 0;
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
   int window=window();
   double mva,atr;

   int counted_bars=IndicatorCounted();
   if(counted_bars<0)
     {
      return -1;
     }
   if(counted_bars>0)
     {
      counted_bars--;
     }
   int limit=Bars-counted_bars;

   if(counted_bars==0)
     {
      limit-=VC_Period+1;
     }

   for(int i=0; i<=limit; i++)
     {
      mva=MVA(i);
      atr=ATR(i);

      VC_Open[i]=(Open[i]-mva)/atr;
      VC_High[i]=(High[i]-mva)/atr;
      VC_Low[i]=(Low[i]-mva)/atr;
      VC_Close[i]=(Close[i]-mva)/atr;

      if(VC_Embed==false)
        {
         draw_candle(window,i);
         if(VC_Signal && i==0)
           {
            send_notification();
           }
        }
     }
   return 0;
  }
//+------------------------------------------------------------------+
//| Seek indicator window                                            |
//+------------------------------------------------------------------+
int window()
  {
   return WindowFind(IndicatorName);
  }
//+------------------------------------------------------------------+
//| Market Value Added function                                      |
//+------------------------------------------------------------------+
double MVA(int shift)
  {
   double sum=0;

   for(int k=shift; k<VC_Period+shift; k++)
     {
      sum+=((High[k]+Low[k])/2.0);
     }

   return sum/VC_Period;
  }
//+------------------------------------------------------------------+
//| Average True Range function                                      |
//+------------------------------------------------------------------+
double ATR(int shift)
  {
   double sum=0,atr;

   for(int k=shift; k<VC_Period+shift; k++)
     {
      sum+=(High[k]-Low[k]);
     }

   atr=sum/VC_Period*0.2;

   if(atr==0.0)
     {
      // avoid division by zero in edge cases
      atr=0.00000001;
     }

   return atr;
  }
//+------------------------------------------------------------------+
//| Return whether the market is neutral, oversold, or overbought    |
//+------------------------------------------------------------------+
int state(int shift)
  {
   if(
      VC_High[shift]>VC_Signal_Limit && 
      VC_Low[shift]<-VC_Signal_Limit
      )
     {
      return STATE_NEUTRAL;
     }
   if(VC_High[shift]>VC_Signal_Limit)
     {
      return STATE_OVERBOUGHT;
     }
   if(VC_Low[shift]<-VC_Signal_Limit)
     {
      return STATE_OVERSOLD;
     }
   return STATE_NEUTRAL;
  }
//+------------------------------------------------------------------+
//| Draw chart candle in the indicator window using objects          |
//+------------------------------------------------------------------+
void draw_candle(int window,int shift)
  {
   color col;

   string hl="VC_HL_"+(string)(int)Time[shift];
   string oc="VC_OC_"+(string)(int)Time[shift];

   if(VC_Signal)
     {
      switch(state(shift))
        {
         case STATE_OVERBOUGHT:
            col=VC_Bear_Candle;
            break;
         case STATE_OVERSOLD:
            col=VC_Bull_Candle;
            break;
         default:
            col=Gray;
            break;
        }
     }
   else
     {
      if(VC_Open[shift]>VC_Close[shift])
        {
         col=VC_Bear_Candle;
        }
      else
        {
         col=VC_Bull_Candle;
        }
     }

   ObjectDelete(window,hl);
   ObjectCreate(hl,OBJ_TREND,window,Time[shift],VC_High[shift],Time[shift],VC_Low[shift]);
   ObjectSet(hl,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSet(hl,OBJPROP_RAY,FALSE);
   ObjectSet(hl,OBJPROP_WIDTH,1);
   ObjectSet(hl,OBJPROP_COLOR,col);
   ObjectDelete(window,oc);

   ObjectCreate(oc,OBJ_TREND,window,Time[shift],VC_Open[shift],Time[shift],VC_Close[shift]);
   ObjectSet(oc,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSet(oc,OBJPROP_RAY,FALSE);
   ObjectSet(oc,OBJPROP_WIDTH,3);
   ObjectSet(oc,OBJPROP_COLOR,col);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void send_notification()
  {
   if(VC_Notify[0]!=EMPTY_VALUE)
     {
      return;
     }
   string action,message;
   switch(state(0))
     {
      case STATE_OVERBOUGHT:
         action=VC_Sell_Message;
         break;
      case STATE_OVERSOLD:
         action=VC_Buy_Message;
         break;
      default:
         return;
         break;
     }
   message=NAME+" - "+Symbol()+" - "+chart_period()+
           " - "+action+" Signal - at: "+
           TimeToStr(TimeLocal(),TIME_SECONDS)+" - price: "
           +(string)Bid;
   if(VC_Notify_Alert)
     {
      Alert(message);
     }
   if(VC_Notify_Push)
     {
      SendNotification(message);
     }
   if(VC_Notify_Email)
     {
      SendMail(action+" Signal",message);
     }
   VC_Notify[0]=1;
  }
//+------------------------------------------------------------------+
//| Returns the string representation of a chart period              |
//+------------------------------------------------------------------+
string chart_period()
  {
   string result[];
   ushort separator=StringGetCharacter("_",0);
   StringSplit(EnumToString(ChartPeriod()),separator,result);
   return result[1];
  }
//+------------------------------------------------------------------+
