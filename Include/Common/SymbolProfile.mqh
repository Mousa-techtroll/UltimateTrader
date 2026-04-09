//+------------------------------------------------------------------+
//| SymbolProfile.mqh                                                |
//| Runtime profile overrides — set by ApplySymbolProfile() in OnInit|
//| Plugins read these instead of raw Inp* for profile-aware params  |
//+------------------------------------------------------------------+
#ifndef SYMBOL_PROFILE_GLOBALS_MQH
#define SYMBOL_PROFILE_GLOBALS_MQH

// These are set in OnInit by ApplySymbolProfile() BEFORE any plugin runs.
// Default to matching the input values (gold profile).
bool   g_profileBearPinBarAsiaOnly  = true;
bool   g_profileBullMACrossBlockNY  = true;
bool   g_profileRubberBandAPlusOnly = true;
bool   g_profileLongExtensionFilter = true;
bool   g_profileEnableCIScoring     = true;
bool   g_profileEnableBearishEngulfing = false;
bool   g_profileEnableS6Short       = false;
bool   g_profileEnableCrashBreakout = true;   // Rubber Band / Death Cross
bool   g_profileEnableBearishPinBar = true;   // Bearish Pin Bar
double g_profileShortRiskMultiplier = 0.5;

#endif
