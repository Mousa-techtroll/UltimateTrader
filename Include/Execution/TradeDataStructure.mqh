//+------------------------------------------------------------------+
//|                                         TradeDataStructure.mqh |
//|                      Contains structures for trade data storage  |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

// Valid order types enumeration for clarity and type safety
enum ENUM_TRADE_ACTION
{
   TRADE_ACTION_BUY,              // Market buy order
   TRADE_ACTION_SELL,             // Market sell order
   TRADE_ACTION_BUY_LIMIT,        // Buy limit pending order
   TRADE_ACTION_SELL_LIMIT,       // Sell limit pending order
   TRADE_ACTION_BUY_STOP,         // Buy stop pending order
   TRADE_ACTION_SELL_STOP,        // Sell stop pending order
   TRADE_ACTION_BUY_STOP_LIMIT,   // Buy stop limit pending order
   TRADE_ACTION_SELL_STOP_LIMIT,  // Sell stop limit pending order
   TRADE_ACTION_UNKNOWN           // Unknown or invalid action
};

// Structure to hold trade data
struct TradeData
{
   datetime Time;              // Trade execution time
   string Symbol;              // Trading symbol
   string Action;              // Trade action (BUY/SELL/BUY_LIMIT/etc.)
   double MaxRiskPercent;      // Maximum risk percentage for this trade
   double EntryPrice;          // Entry/activation price for the trade
   double EntryPriceMax;       // Maximum entry price (for range entries)
   double LimitPrice;          // Limit price (for stop-limit orders)
   double StopLoss;            // Stop loss level
   double TakeProfit1;         // Take profit level 1
   double TakeProfit2;         // Take profit level 2
   double TakeProfit3;         // Take profit level 3
   datetime Expiration;        // Expiration time for pending orders (0 = GTC)
   bool Executed;              // Flag to track if trade has been executed
   int MagicNumber;            // Unique magic number for the trade
   ulong PositionTicket;       // Position ticket number
   ulong OrderTicket;          // Order ticket number for pending orders
   double LotSize;             // Lot size for the trade
   bool TP1Hit;                // Flag to track if TP1 has been hit
   bool TP2Hit;                // Flag to track if TP2 has been hit
   int ConfirmationCount;      // Counter for confirmation candles in trailing
   datetime LastTrailUpdate;   // Time of last trail update
   double LastTrailPrice;      // Price at last trail update
   bool UseTP2AsTarget;        // Flag to use TP2 as main target
   bool UseTP3AsTarget;        // Flag to use TP3 as main target

   // Constructor - MQL5 requires initialization function instead of constructor
   void Init()
   {
      Time = 0;
      Symbol = "";
      Action = "";
      MaxRiskPercent = 0.0;
      EntryPrice = 0.0;
      EntryPriceMax = 0.0;
      LimitPrice = 0.0;         // New field for stop-limit orders
      StopLoss = 0.0;
      TakeProfit1 = 0.0;
      TakeProfit2 = 0.0;
      TakeProfit3 = 0.0;
      Expiration = 0;           // New field for pending order expiration
      Executed = false;
      MagicNumber = 0;
      PositionTicket = 0;
      OrderTicket = 0;          // New field for tracking pending orders
      LotSize = 0.0;
      TP1Hit = false;
      TP2Hit = false;
      ConfirmationCount = 0;
      LastTrailUpdate = 0;
      LastTrailPrice = 0.0;
      UseTP2AsTarget = false;
      UseTP3AsTarget = false;
   }
};