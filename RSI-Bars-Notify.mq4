//+------------------------------------------------------------------+
//|                                              RSI-Bars-Notify.mq4 |
//|                                                      Stefan Rusu |
//|                                             saltwaterc@gmail.com |
//+------------------------------------------------------------------+
#property copyright "Stefan Rusu"
#property link      "saltwaterc@gmail.com"
#property version   "1.00"
#property strict
#property indicator_separate_window
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_buffers 2
//+------------------------------------------------------------------+
//| ENUM_APPLIED_PRICE as input                                      |
//+------------------------------------------------------------------+
enum ApplyTo
  {
   CLOSE=PRICE_CLOSE,
   OPEN=PRICE_OPEN,
   HIGH=PRICE_HIGH,
   LOW=PRICE_LOW,
   MEDIAN=PRICE_MEDIAN,
   TYPICAL=PRICE_TYPICAL,
   WEIGHTED=PRICE_WEIGHTED
  };
//+------------------------------------------------------------------+
//| The notification style                                           |
//+------------------------------------------------------------------+
enum NotificationStyle
  {
   NONE=0,
   ZIGZAG=1,
   EVERY_CANDLE=2
  };
//--- constants
#define NAME "RSI"
#define SIGNAL_SELL NAME + "_signal_sell"
#define SIGNAL_BUY NAME + "_signal_buy"
#define ARROW_SELL NAME + "_arrow_sell_"
#define ARROW_BUY NAME + "_arrow_buy_"

//--- buffers
double RSI[];
double NOTIFY[];

//--- inputs
input int PERIOD=14;
input ApplyTo APPLY_TO=CLOSE;
input int OVERBOUGHT=70;
input int OVERSOLD=30;
input int BAR_WIDTH=3;
input color BAR_COLOUR=DodgerBlue;
input color BAR_SELL=Red;
input color BAR_BUY=Lime;
input string SELL_MESSAGE="SELL";
input string BUY_MESSAGE="BUY";
input bool NOTIFICATIONS=true;
input NotificationStyle NOTIFICATION_STYLE=EVERY_CANDLE;
input bool NOTIFY_ALERT=true;
input bool NOTIFY_PUSH=true;
input bool NOTIFY_EMAIL=false;
input bool ARROWS=true;

//--- global variables
string IndicatorName=NAME+"("+(string)PERIOD+") Bars Notify";
bool DelayedInit=false;
int LastNotification=0;
double PriceShift=MathPow(10,-(Digits-1));
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int init()
  {
   IndicatorShortName(IndicatorName);

   SetIndexStyle(0,DRAW_NONE);
   SetIndexLabel(0,NAME+"("+(string)PERIOD+")");
   SetIndexBuffer(0,RSI);

   SetIndexStyle(1,DRAW_NONE);
   SetIndexLabel(1,NULL);
   SetIndexBuffer(1,NOTIFY);

   return 0;
  }
//+------------------------------------------------------------------+
//| Custom deinitialisation function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
   int i;
   for(i=0;i<Bars;i++)
     {
      clear_arrows(i);
     }
   ObjectsDeleteAll(window());
   return 0;
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int start()
  {
   delayed_init();

   int window=window();
   int i,limit,counted=IndicatorCounted();
// last counted bar will be recounted
   if(counted>0)
     {
      counted--;
     }
   limit=Bars-counted;
   if(counted==0)
     {
      limit-=2;
     }

   for(i=limit;i>=0;i--)
     {
      RSI[i]=iRSI(NULL,0,PERIOD,ENUM_APPLIED_PRICE(APPLY_TO),i);
      draw_bar(window,i);
      draw_arrow(i);
      if(i==0)
        {
         send_notification();
        }
     }
   return 0;
  }
//+------------------------------------------------------------------+
//| Draw RSI bar in indicator window                                 |
//+------------------------------------------------------------------+
void draw_bar(int window,int shift)
  {
   string name=NAME+"_Bars_Notify_"+(string)(int)Time[shift];
   color col=BAR_COLOUR;

   if(RSI[shift]>OVERBOUGHT)
     {
      col=BAR_SELL;
     }
   if(RSI[shift]<OVERSOLD)
     {
      col=BAR_BUY;
     }

   ObjectDelete(name);
   ObjectCreate(
                name,
                OBJ_TREND,
                window,
                Time[shift],
                50,
                Time[shift],
                RSI[shift]
                );
   ObjectSet(name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSet(name,OBJPROP_RAY,FALSE);
   ObjectSet(name,OBJPROP_WIDTH,BAR_WIDTH);
   ObjectSet(name,OBJPROP_COLOR,col);
  }
//+------------------------------------------------------------------+
//| Draw sell/buy arrows on the main chart                           |
//+------------------------------------------------------------------+
void draw_arrow(int shift)
  {
   bool arrow=false;
   string name;
   double price=0;
   int code=0;
   color clr=0;
   if(!ARROWS)
     {
      return;
     }
   if(RSI[shift]>=OVERBOUGHT)
     {
      arrow=true;
      name=ARROW_SELL+(string)Time[shift];
      price=High[shift];
      code=234;
      clr=BAR_SELL;
     }
   if(RSI[shift]<=OVERSOLD)
     {
      arrow=true;
      name=ARROW_BUY+(string)Time[shift];
      price=Low[shift];
      code=233;
      clr=BAR_BUY;
     }
   if(arrow)
     {
      ObjectDelete(name);
      ObjectCreate(name,OBJ_ARROW,0,Time[shift],price+PriceShift);
      ObjectSet(name,OBJPROP_ARROWCODE,code);
      ObjectSet(name,OBJPROP_COLOR,clr);
      ObjectSet(name,OBJPROP_WIDTH,0);
      WindowRedraw();
     }
   else
     {
      clear_arrows(shift);
     }
  }
//+------------------------------------------------------------------+
//| init() can't draw objects on the indicator window                |
//+------------------------------------------------------------------+
void delayed_init()
  {
   if(DelayedInit==true)
     {
      return;
     }

   int window=window();

   ObjectCreate(SIGNAL_SELL,OBJ_HLINE,window,0,OVERBOUGHT);
   ObjectSet(SIGNAL_SELL,OBJPROP_COLOR,BAR_SELL);

   ObjectCreate(SIGNAL_BUY,OBJ_HLINE,window,0,OVERSOLD);
   ObjectSet(SIGNAL_BUY,OBJPROP_COLOR,BAR_BUY);

   WindowRedraw();

   DelayedInit=true;
  }
//+------------------------------------------------------------------+
//| Handle all notification types                                    |
//+------------------------------------------------------------------+
void send_notification()
  {
   if(!NOTIFICATIONS)
     {
      return;
     }

   bool notify=false;
   string action="";
   switch(NOTIFICATION_STYLE)
     {
      case ZIGZAG:
         if(LastNotification!=1 && RSI[0]>=OVERBOUGHT)
           {
            LastNotification=1;
            notify=true;
            action=SELL_MESSAGE;
           }

         if(LastNotification!=2 && RSI[0]<=OVERSOLD)
           {
            LastNotification=2;
            notify=true;
            action=BUY_MESSAGE;
           }
         break;
      case EVERY_CANDLE:
         if(NOTIFY[0]!=EMPTY_VALUE)
           {
            return;
           }

         if(RSI[0]>=OVERBOUGHT)
           {
            notify=true;
            action=SELL_MESSAGE;
            NOTIFY[0]=1;
           }

         if(RSI[0]<=OVERSOLD)
           {
            notify=true;
            action=BUY_MESSAGE;
            NOTIFY[0]=1;
           }
         break;
     }

   if(notify)
     {
      string message=NAME+" - "+Symbol()+" - "+chart_period()+
                     " - "+action+" Signal - at: "+
                     TimeToStr(TimeLocal(),TIME_SECONDS)+" - price: "
                     +(string)Bid;
      if(NOTIFY_ALERT)
        {
         Alert(message);
        }
      if(NOTIFY_PUSH)
        {
         SendNotification(message);
        }
      if(NOTIFY_EMAIL)
        {
         SendMail(action+" Signal",message);
        }
     }
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
//| Seek indicator window                                            |
//+------------------------------------------------------------------+
int window()
  {
   return WindowFind(IndicatorName);
  }
//+------------------------------------------------------------------+
//|Clear call/put arrows for specified bar                           |
//+------------------------------------------------------------------+
void clear_arrows(int shift)
  {
   ObjectDelete(ARROW_SELL+(string)Time[shift]);
   ObjectDelete(ARROW_BUY+(string)Time[shift]);
  }
//+------------------------------------------------------------------+
