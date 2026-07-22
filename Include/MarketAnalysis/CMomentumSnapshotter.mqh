//+------------------------------------------------------------------+
//| CMomentumSnapshotter.mqh                                         |
//| FROZEN public interface (WAVE 0 stub) — Exit-Momentum Platform    |
//|                                                                  |
//| Produces the closed-bar MomentumSnapshot (12 outputs) + the six   |
//| IntentScores, availability-aware (never fabricates a neutral      |
//| value). Owned by CMarketContext; Update() is driven once per H1   |
//| bar AFTER CBearStateModel.Update(), and gated on the exit-policy  |
//| master flags so the default build does zero extra per-bar work.   |
//|                                                                  |
//| THIS IS A STUB. Builder A1 replaces the bodies with the real P1   |
//| feature computations WITHOUT changing these public signatures     |
//| (W2.5 diffs the interface). The stub returns not-ready / all-     |
//| unavailable so the plumbing (W1) compiles + is byte-identical.    |
//+------------------------------------------------------------------+
#ifndef ULTIMATETRADER_CMOMENTUMSNAPSHOTTER_MQH
#define ULTIMATETRADER_CMOMENTUMSNAPSHOTTER_MQH

#include "../Common/Structs.mqh"

// Forward declaration — the snapshotter reads closed-bar market state via its owning
// context's public getters (+ its own private RSI/MA handles). Pointer-only use, so a
// forward declaration avoids a circular include with CMarketContext.
class CMarketContext;

//+------------------------------------------------------------------+
//| CMomentumSnapshotter — pure closed-bar momentum producer.         |
//+------------------------------------------------------------------+
class CMomentumSnapshotter
{
private:
   CMarketContext   *m_ctx;        // owner/context for component reads (not owned)
   bool              m_ready;      // warmup complete + all required handles valid
   MomentumSnapshot  m_snapshot;   // cached, refreshed once per closed H1 bar

public:
                     CMomentumSnapshotter() { m_ctx = NULL; m_ready = false; m_snapshot.Init(); }
   virtual          ~CMomentumSnapshotter() {}

   // Bind to the owning context + create private indicator handles. A1 fills this.
   // FROZEN SIGNATURE.
   virtual bool      Init(CMarketContext *ctx) { m_ctx = ctx; m_ready = false; return true; }

   // Recompute the snapshot from the just-closed H1 bar. Caller passes iTime(H1,1).
   // Closed-bar only (shift >= 1). A1 fills this. FROZEN SIGNATURE.
   virtual void      Update(datetime closed_h1_bar) { /* stub: no-op, stays not-ready */ }

   // Copy the cached snapshot out (by-ref, no return copy). FROZEN SIGNATURE.
   virtual void      GetSnapshot(MomentumSnapshot &out) const { out = m_snapshot; }

   // Fill the six 0..100 intent scores; pos disambiguates the crash intent. A1 fills.
   // FROZEN SIGNATURE.
   virtual void      GetIntentScores(const SPosition &pos, IntentScores &out) const { out.Init(); }

   // True once warmed + producing valid features. FROZEN SIGNATURE.
   virtual bool      IsReady() const { return m_ready; }
};

#endif // ULTIMATETRADER_CMOMENTUMSNAPSHOTTER_MQH
