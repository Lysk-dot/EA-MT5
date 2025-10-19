//+------------------------------------------------------------------+
//| DataCollector.mq5                                                |
//| Improved Data Collection System                                  |
//+------------------------------------------------------------------+

#property copyright "Enhanced Data Collector"
#property version   "2.0"
#property strict

#include <Trade\Trade.mqh>
#include <Arrays\ArrayDouble.mqh>

//--- Configuration
input int      ATR_Period = 14;
input int      MA_Period = 14;
input int      MA_Shift = 0;
input ENUM_MA_METHOD MA_Method = MODE_SMA;
input int      Stochastic_K = 5;
input int      Stochastic_D = 3;
input int      Stochastic_Slowing = 3;
input ENUM_STO_PRICE Stochastic_Price = STO_LOWHIGH;
input double   Bands_Deviation = 2.0;

//--- Global variables
int            atr_handle;
int            ma_handle;
int            stoch_handle;
int            bands_handle;
double         current_prices[];
MqlTick        current_tick;
CArrayDouble   price_data;
CTrade         trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== Initializing Enhanced Data Collector ===");
    
    // Initialize indicator handles
    atr_handle = iATR(_Symbol, _Period, ATR_Period);
    ma_handle = iMA(_Symbol, _Period, MA_Period, MA_Shift, MA_Method, PRICE_CLOSE);
    stoch_handle = iStochastic(_Symbol, _Period, Stochastic_K, Stochastic_D, Stochastic_Slowing, MA_Method, Stochastic_Price);
    bands_handle = iBands(_Symbol, _Period, MA_Period, MA_Shift, Bands_Deviation, PRICE_CLOSE);
    
    // Verify indicator handles
    if(atr_handle == INVALID_HANDLE)
        Print("Error: Failed to create ATR indicator handle");
    if(ma_handle == INVALID_HANDLE)
        Print("Error: Failed to create MA indicator handle");
    if(stoch_handle == INVALID_HANDLE)
        Print("Error: Failed to create Stochastic indicator handle");
    if(bands_handle == INVALID_HANDLE)
        Print("Error: Failed to create Bollinger Bands indicator handle");
    
    // Initialize price array
    ArraySetAsSeries(current_prices, true);
    
    Print("Data Collector initialized successfully");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(IsNewBar())
    {
        CollectMarketData();
        ProcessIndicators();
        SaveDataToFile();
    }
}

//+------------------------------------------------------------------+
//| Check for new bar                                               |
//+------------------------------------------------------------------+
bool IsNewBar()
{
    static datetime last_bar = 0;
    datetime current_bar = iTime(_Symbol, _Period, 0);
    
    if(current_bar != last_bar)
    {
        last_bar = current_bar;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Collect market data                                             |
//+------------------------------------------------------------------+
void CollectMarketData()
{
    // Get current tick data
    if(SymbolInfoTick(_Symbol, current_tick))
    {
        // Store prices
        double ask = current_tick.ask;
        double bid = current_tick.bid;
        double spread = ask - bid;
        
        // Add to price collection
        price_data.Add(ask);
        price_data.Add(bid);
        price_data.Add(spread);
        
        Print(StringFormat("Tick: Ask=%.5f, Bid=%.5f, Spread=%.5f", ask, bid, spread));
    }
    else
    {
        Print("Error: Failed to get tick data");
    }
}

//+------------------------------------------------------------------+
//| Process technical indicators                                    |
//+------------------------------------------------------------------+
void ProcessIndicators()
{
    double atr_values[1];
    double ma_values[1];
    double stoch_main[1], stoch_signal[1];
    double bands_upper[1], bands_middle[1], bands_lower[1];
    
    // Get ATR values
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_values) > 0)
    {
        Print(StringFormat("ATR[%d]: %.5f", ATR_Period, atr_values[0]));
    }
    
    // Get MA values
    if(CopyBuffer(ma_handle, 0, 0, 1, ma_values) > 0)
    {
        Print(StringFormat("MA[%d]: %.5f", MA_Period, ma_values[0]));
    }
    
    // Get Stochastic values
    if(CopyBuffer(stoch_handle, 0, 0, 1, stoch_main) > 0 && 
       CopyBuffer(stoch_handle, 1, 0, 1, stoch_signal) > 0)
    {
        Print(StringFormat("Stochastic: Main=%.2f, Signal=%.2f", stoch_main[0], stoch_signal[0]));
    }
    
    // Get Bollinger Bands values
    if(CopyBuffer(bands_handle, 0, 0, 1, bands_upper) > 0 &&
       CopyBuffer(bands_handle, 1, 0, 1, bands_middle) > 0 &&
       CopyBuffer(bands_handle, 2, 0, 1, bands_lower) > 0)
    {
        Print(StringFormat("Bollinger Bands: Upper=%.5f, Middle=%.5f, Lower=%.5f", 
              bands_upper[0], bands_middle[0], bands_lower[0]));
    }
}

//+------------------------------------------------------------------+
//| Save data to file                                               |
//+------------------------------------------------------------------+
void SaveDataToFile()
{
    string filename = "MarketData_" + _Symbol + "_" + IntegerToString((int)_Period) + ".csv";
    int file_handle = FileOpen(filename, FILE_READ | FILE_WRITE | FILE_CSV | FILE_COMMON);
    
    if(file_handle != INVALID_HANDLE)
    {
        // Go to end of file
        FileSeek(file_handle, 0, SEEK_END);
        
        // If file is empty, write header
        if(FileTell(file_handle) == 0)
        {
            FileWrite(file_handle, "DateTime,Symbol,Period,Ask,Bid,Spread,ATR,MA,Stoch_Main,Stoch_Signal,Bands_Upper,Bands_Middle,Bands_Lower");
        }
        
        // Get current time
        MqlDateTime dt;
        TimeCurrent(dt);
        string datetime_str = StringFormat("%04d.%02d.%02d %02d:%02d", 
                         dt.year, dt.mon, dt.day, dt.hour, dt.min);
        
        // Get indicator values for current bar
        double atr_val[1], ma_val[1], stoch_m[1], stoch_s[1];
        double bands_u[1], bands_m[1], bands_l[1];
        
        CopyBuffer(atr_handle, 0, 0, 1, atr_val);
        CopyBuffer(ma_handle, 0, 0, 1, ma_val);
        CopyBuffer(stoch_handle, 0, 0, 1, stoch_m);
        CopyBuffer(stoch_handle, 1, 0, 1, stoch_s);
        CopyBuffer(bands_handle, 0, 0, 1, bands_u);
        CopyBuffer(bands_handle, 1, 0, 1, bands_m);
        CopyBuffer(bands_handle, 2, 0, 1, bands_l);
        
        // Write data row
        FileWrite(file_handle,
                 datetime_str,
                 _Symbol,
                 IntegerToString((int)_Period),
                 DoubleToString(current_tick.ask, _Digits),
                 DoubleToString(current_tick.bid, _Digits),
                 DoubleToString(current_tick.ask - current_tick.bid, _Digits),
                 DoubleToString(atr_val[0], _Digits),
                 DoubleToString(ma_val[0], _Digits),
                 DoubleToString(stoch_m[0], 2),
                 DoubleToString(stoch_s[0], 2),
                 DoubleToString(bands_u[0], _Digits),
                 DoubleToString(bands_m[0], _Digits),
                 DoubleToString(bands_l[0], _Digits));
        
        FileClose(file_handle);
        Print("Data saved to: " + filename);
    }
    else
    {
        Print("Error: Failed to open file: " + filename);
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Release indicator handles
    if(atr_handle != INVALID_HANDLE) IndicatorRelease(atr_handle);
    if(ma_handle != INVALID_HANDLE) IndicatorRelease(ma_handle);
    if(stoch_handle != INVALID_HANDLE) IndicatorRelease(stoch_handle);
    if(bands_handle != INVALID_HANDLE) IndicatorRelease(bands_handle);
    
    Print("Data Collector deinitialized. Reason: " + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| Utility Functions                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get current market information                                  |
//+------------------------------------------------------------------+
string GetMarketInfo()
{
    string info = "=== Market Information ===\n";
    info += StringFormat("Symbol: %s\n", _Symbol);
    info += StringFormat("Period: %s\n", PeriodToString(_Period));
    info += StringFormat("Digits: %d\n", _Digits);
    info += StringFormat("Point: %.5f\n", _Point);
    info += StringFormat("Ask: %.5f\n", current_tick.ask);
    info += StringFormat("Bid: %.5f\n", current_tick.bid);
    info += StringFormat("Spread: %.5f\n", current_tick.ask - current_tick.bid);
    
    return info;
}

//+------------------------------------------------------------------+
//| Convert period to string                                        |
//+------------------------------------------------------------------+
string PeriodToString(ENUM_TIMEFRAMES period)
{
    switch(period)
    {
        case PERIOD_M1: return "M1";
        case PERIOD_M5: return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1: return "H1";
        case PERIOD_H4: return "H4";
        case PERIOD_D1: return "D1";
        case PERIOD_W1: return "W1";
        case PERIOD_MN1: return "MN1";
        default: return "Unknown";
    }
}