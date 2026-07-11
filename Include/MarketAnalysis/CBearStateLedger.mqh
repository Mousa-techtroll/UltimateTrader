//+------------------------------------------------------------------+
//|                                           CBearStateLedger.mqh    |
//|   UltimateTrader - SB-1.1 ledger SOURCE for the bear-state stamp  |
//|                                                                   |
//|   Reads the frozen, Python-validated per-H1-bar bear-state labels |
//|   from a CSV in the terminal Common\Files directory and serves    |
//|   them behind the SAME CMarketContext getters the computed        |
//|   CBearStateModel serves (GetState/GetScore/GetAgeH4). Selected    |
//|   by InpBearStateSource=LEDGER so the CREV experiment consumes the |
//|   exact validated states, not the ~97.4%-faithful in-EA model      |
//|   (closing that gap is a separate live-port fidelity task).        |
//|                                                                   |
//|   STRICT no-look-ahead: at decision time the forming H1 bar is     |
//|   index 0, so the newest row served is the greatest ledger key     |
//|   <= the LAST CLOSED H1 bar iTime(PERIOD_H1,1) — NEVER the         |
//|   forming bar index 0. The Python row for BarTime=T was computed   |
//|   from data through T's close, so it is safe to consume when       |
//|   deciding on bar T+1. DECISION-FREE for now (CREV is next).       |
//|                                                                   |
//|   CSV format (comma-delimited, terminal Common\Files):             |
//|      BarTime,State,Score,StateAgeH4                                |
//|      2019.01.02 01:00,BULL_TREND,0,114                             |
//|   The reader mirrors CNewsGate::LoadCsv exactly (the proven        |
//|   pattern): FILE_ANSI|FILE_TXT|FILE_COMMON, then non-COMMON        |
//|   fallback; FileReadString + StringSplit + StringToTime.          |
//+------------------------------------------------------------------+
#property copyright "UltimateTrader"
#property version   "1.00"
#property strict

#ifndef ULTIMATETRADER_CBEARSTATELEDGER_MQH
#define ULTIMATETRADER_CBEARSTATELEDGER_MQH

#include "../Common/Enums.mqh"

//+------------------------------------------------------------------+
//| CBearStateLedger                                                  |
//+------------------------------------------------------------------+
class CBearStateLedger
{
private:
   //--- Time-sorted ledger rows (parallel arrays, oldest-first).
   datetime          m_time[];
   ENUM_BEAR_STATE   m_state[];
   int               m_score[];
   int               m_age[];
   int               m_count;

   //--- Verification dump (mirrors CBearStateModel's ledger writer).
   bool              m_ledger_enabled;
   int               m_dump_handle;
   string            m_dump_name;
   datetime          m_last_h1_stamp;   // one dump row per H1 bar

   //--- Cached stamp for the current decision bar (set each Update()).
   ENUM_BEAR_STATE   m_cur_state;
   int               m_cur_score;
   int               m_cur_age;
   long              m_prehistory_hits; // closed bars with no ledger key <= them

public:
   CBearStateLedger()
   {
      m_count           = 0;
      m_ledger_enabled  = false;
      m_dump_handle     = INVALID_HANDLE;
      m_dump_name       = "";
      m_last_h1_stamp   = 0;
      m_cur_state       = BEAR_STATE_BULL_TREND;
      m_cur_score       = 0;
      m_cur_age         = 0;
      m_prehistory_hits = 0;
   }

   ~CBearStateLedger()
   {
      if(m_prehistory_hits > 0)
         Print("[BearState] ledger: ", m_prehistory_hits,
               " closed bar(s) before ledger horizon — neutral default served");
      if(m_dump_handle != INVALID_HANDLE)
      {
         FileClose(m_dump_handle);
         m_dump_handle = INVALID_HANDLE;
      }
   }

   void SetLedgerEnabled(bool en) { m_ledger_enabled = en; }

   //--- Read-only accessors (same shape as CBearStateModel).
   ENUM_BEAR_STATE GetState() const { return m_cur_state; }
   int             GetScore() const { return m_cur_score; }
   int             GetAgeH4() const { return m_cur_age; }

   //+---------------------------------------------------------------+
   //| Load the frozen ledger. Returns false (FATAL to the owning     |
   //| CMarketContext::Init) if the file is unreadable or empty — a    |
   //| silent fallback to COMPUTED would confound the CREV experiment. |
   //+---------------------------------------------------------------+
   bool Initialize(string filename)
   {
      int handle = FileOpen(filename, FILE_READ | FILE_ANSI | FILE_TXT | FILE_COMMON);
      if(handle == INVALID_HANDLE)
         handle = FileOpen(filename, FILE_READ | FILE_ANSI | FILE_TXT);
      if(handle == INVALID_HANDLE)
      {
         ResetLastError();
         Print("[BearState] ledger FATAL: cannot open '", filename,
               "' in Common\\Files or terminal Files");
         return false;
      }

      m_count = 0;
      int malformed = 0;
      int reserve = 65536;
      ArrayResize(m_time,  0, reserve);
      ArrayResize(m_state, 0, reserve);
      ArrayResize(m_score, 0, reserve);
      ArrayResize(m_age,   0, reserve);

      while(!FileIsEnding(handle))
      {
         string line = FileReadString(handle);
         StringTrimRight(line);
         StringTrimLeft(line);
         if(StringLen(line) == 0)
            continue;
         if(StringFind(line, "BarTime") == 0)   // header line
            continue;

         string parts[];
         int k = StringSplit(line, ',', parts);
         if(k < 4)
         {
            malformed++;
            continue;
         }

         datetime t = StringToTime(parts[0]);
         if(t <= 0)
         {
            malformed++;
            continue;
         }

         ArrayResize(m_time,  m_count + 1, reserve);
         ArrayResize(m_state, m_count + 1, reserve);
         ArrayResize(m_score, m_count + 1, reserve);
         ArrayResize(m_age,   m_count + 1, reserve);
         m_time[m_count]  = t;
         m_state[m_count] = StringToBearState(parts[1]);
         m_score[m_count] = (int)StringToInteger(parts[2]);
         m_age[m_count]   = (int)StringToInteger(parts[3]);
         m_count++;
      }
      FileClose(handle);

      if(m_count == 0)
      {
         Print("[BearState] ledger FATAL: '", filename, "' parsed 0 rows");
         return false;
      }

      SortByTime();

      Print("[BearState] ledger loaded: ", m_count, " rows, horizon ",
            TimeToString(m_time[0], TIME_DATE | TIME_MINUTES), "..",
            TimeToString(m_time[m_count - 1], TIME_DATE | TIME_MINUTES),
            malformed > 0 ? StringFormat(" (%d malformed skipped)", malformed) : "");
      return true;
   }

   //+---------------------------------------------------------------+
   //| Once-per-new-H1-bar refresh. Called from CMarketContext::      |
   //| Update() which already gates once-per-new-H1-bar. Keys STRICTLY |
   //| on the last CLOSED H1 bar iTime(PERIOD_H1,1); NEVER the forming |
   //| bar index 0 — that is what makes the lookup no-look-ahead.      |
   //+---------------------------------------------------------------+
   void Update()
   {
      datetime closed = iTime(_Symbol, PERIOD_H1, 1);
      if(closed <= 0)
         return;                              // no closed bar yet

      int idx = FindLE(closed);
      if(idx < 0)
      {
         m_cur_state = BEAR_STATE_BULL_TREND;  // pre-history neutral default
         m_cur_score = 0;
         m_cur_age   = 0;
         m_prehistory_hits++;
      }
      else
      {
         m_cur_state = m_state[idx];
         m_cur_score = m_score[idx];
         m_cur_age   = m_age[idx];
      }
      WriteDumpRow(closed);
   }

private:
   //+---------------------------------------------------------------+
   //| Binary search: greatest index with m_time[idx] <= target, or   |
   //| -1 if every key is later than target (pre-history).            |
   //+---------------------------------------------------------------+
   int FindLE(datetime target) const
   {
      int lo = 0, hi = m_count - 1, res = -1;
      while(lo <= hi)
      {
         int mid = (lo + hi) >> 1;
         if(m_time[mid] <= target) { res = mid; lo = mid + 1; }
         else                        hi = mid - 1;
      }
      return res;
   }

   //+---------------------------------------------------------------+
   //| Insertion sort by time (the exporter emits chronological rows, |
   //| so this is near-O(n)) — mirrors CNewsGate::SortAndDedupe.      |
   //+---------------------------------------------------------------+
   void SortByTime()
   {
      for(int i = 1; i < m_count; i++)
      {
         datetime        kt  = m_time[i];
         ENUM_BEAR_STATE ks  = m_state[i];
         int             ksc = m_score[i];
         int             ka  = m_age[i];
         int j = i - 1;
         while(j >= 0 && m_time[j] > kt)
         {
            m_time[j + 1]  = m_time[j];
            m_state[j + 1] = m_state[j];
            m_score[j + 1] = m_score[j];
            m_age[j + 1]   = m_age[j];
            j--;
         }
         m_time[j + 1]  = kt;
         m_state[j + 1] = ks;
         m_score[j + 1] = ksc;
         m_age[j + 1]   = ka;
      }
   }

   //+---------------------------------------------------------------+
   //| Verification dump: echo what the lookup served, KEYED ON THE    |
   //| CLOSED bar time, so the PM can diff it 1:1 against the source    |
   //| ledger and confirm the no-look-ahead lookup is exactly          |
   //| time-aligned. Mirrors CBearStateModel::WriteLedgerRow (same     |
   //| filename/format) but reflects the ACTIVE (ledger) source.       |
   //+---------------------------------------------------------------+
   void WriteDumpRow(datetime closed)
   {
      if(!m_ledger_enabled)
         return;
      if(closed == m_last_h1_stamp)
         return;
      m_last_h1_stamp = closed;

      if(m_dump_handle == INVALID_HANDLE)
      {
         m_dump_name = StringFormat("UltTrader_BearStates_%s.csv", _Symbol);
         m_dump_handle = FileOpen(m_dump_name, FILE_WRITE | FILE_CSV | FILE_COMMON, ',');
         if(m_dump_handle == INVALID_HANDLE)
         {
            Print("[BearState] WARNING: could not create ledger dump ", m_dump_name,
                  " (err ", GetLastError(), ")");
            m_ledger_enabled = false;   // stop retrying
            return;
         }
         FileWrite(m_dump_handle, "BarTime", "State", "Score", "StateAgeH4");
      }
      FileWrite(m_dump_handle,
                TimeToString(closed, TIME_DATE | TIME_MINUTES),
                BearStateToString(m_cur_state),
                IntegerToString(m_cur_score),
                IntegerToString(m_cur_age));
   }
};

#endif // ULTIMATETRADER_CBEARSTATELEDGER_MQH
