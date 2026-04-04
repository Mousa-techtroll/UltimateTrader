//+------------------------------------------------------------------+
//|                                CHealthBasedRiskAdjuster.mqh |
//|  Centralized health-based risk adjustment logic              |
//+------------------------------------------------------------------+
#property copyright "Enhanced EA Team"
#property version   "1.0"
#property strict

#include "Logger.mqh"
#include "HealthMonitor.mqh"

//+------------------------------------------------------------------+
//| Class to centralize health-based risk adjustment logic            |
//+------------------------------------------------------------------+
class CHealthBasedRiskAdjuster
{
private:
   Logger*          m_logger;           // Logger instance
   CHealthMonitor*   m_healthMonitor;    // Health monitor for system metrics
   bool              m_useHealthBasedRisk; // Whether to use health-based risk adjustment
   bool              m_enforceHealthChecks; // Whether health checks are enforced
   
   // Minimum adjustment factor (percentage of normal risk when health is at 0%)
   double            m_minimumAdjustment;
   
   // Maximum adjustment factor (percentage of normal risk when health is at 100%)
   double            m_maximumAdjustment;
   
   // Name of the health metric to use for risk adjustment
   string            m_metricName;

public:
   //+------------------------------------------------------------------+
   //| Constructor                                                      |
   //+------------------------------------------------------------------+
   CHealthBasedRiskAdjuster(Logger* logger = NULL, 
                           CHealthMonitor* healthMonitor = NULL,
                           bool useHealthBasedRisk = true,
                           bool enforceHealthChecks = true,
                           string metricName = "TradingCapacity",
                           double minimumAdjustment = 0.5,  // 50% of normal risk at worst health
                           double maximumAdjustment = 1.0)  // 100% of normal risk at best health
   {
      m_logger = logger;
      m_healthMonitor = healthMonitor;
      m_useHealthBasedRisk = useHealthBasedRisk;
      m_enforceHealthChecks = enforceHealthChecks;
      m_metricName = metricName;
      m_minimumAdjustment = MathMax(0.1, MathMin(1.0, minimumAdjustment));  // Ensure between 10-100%
      m_maximumAdjustment = MathMax(m_minimumAdjustment, MathMin(1.0, maximumAdjustment)); // Ensure valid range
      
      if(m_logger != NULL)
      {
         Log.SetComponent("RiskAdjuster");
         Log.Info("Health-based risk adjuster initialized: " + 
                    (m_useHealthBasedRisk ? "Enabled" : "Disabled") + 
                    ", Metric: " + m_metricName + 
                    ", Range: " + DoubleToString(m_minimumAdjustment * 100, 1) + "%-" + 
                    DoubleToString(m_maximumAdjustment * 100, 1) + "%");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Calculate risk adjustment factor based on system health          |
   //+------------------------------------------------------------------+
   double CalculateRiskAdjustment(string context = "")
   {
      // Default to no adjustment
      double riskAdjustment = 1.0;
      
      // Only apply adjustment if all conditions are met
      if(m_useHealthBasedRisk && m_enforceHealthChecks && m_healthMonitor != NULL)
      {
         // Get health metric
         HealthMetric tradingCapacity = m_healthMonitor.GetMetricByName(m_metricName);
         
         // Ensure we're using a valid value (defensive programming)
         double capacityValue = tradingCapacity.value;
         if(capacityValue < 0) capacityValue = 0;
         if(capacityValue > 100) capacityValue = 100;
         
         // Scale risk based on system health using the configured min/max adjustment
         // Formula: minAdjustment + (maxAdjustment - minAdjustment) * healthPercentage
         double range = m_maximumAdjustment - m_minimumAdjustment;
         riskAdjustment = m_minimumAdjustment + (range * capacityValue / 100.0);
         
         // Log the adjustment if logger is available
         if(m_logger != NULL)
         {
            Log.Info("Adjusting risk based on system health (" + 
                       DoubleToString(capacityValue, 1) + "% health): " + 
                       DoubleToString(riskAdjustment * 100, 1) + "% of normal" + 
                       (context != "" ? " for " + context : ""));
         }
      }
      
      return riskAdjustment;
   }
   
   //+------------------------------------------------------------------+
   //| Adjust a risk value based on system health                       |
   //+------------------------------------------------------------------+
   double AdjustRisk(double baseRisk, string context = "")
   {
      double adjustmentFactor = CalculateRiskAdjustment(context);
      double adjustedRisk = baseRisk * adjustmentFactor;
      
      // Log detailed adjustment if logger is available
      if(m_logger != NULL && adjustmentFactor != 1.0)
      {
         Log.Info("Adjusted risk" + (context != "" ? " for " + context : "") + 
                  " from " + DoubleToString(baseRisk, 2) + "% to " + 
                  DoubleToString(adjustedRisk, 2) + "%");
      }
      
      return adjustedRisk;
   }
   
   //+------------------------------------------------------------------+
   //| Enable or disable health-based risk adjustment                   |
   //+------------------------------------------------------------------+
   void SetEnabled(bool enabled)
   {
      m_useHealthBasedRisk = enabled;
      
      if(m_logger != NULL)
      {
         Log.Info("Health-based risk adjustment " + 
                   (enabled ? "enabled" : "disabled"));
      }
   }
   
   //+------------------------------------------------------------------+
   //| Set the health monitor instance                                  |
   //+------------------------------------------------------------------+
   void SetHealthMonitor(CHealthMonitor* healthMonitor)
   {
      m_healthMonitor = healthMonitor;
   }
   
   //+------------------------------------------------------------------+
   //| Configure adjustment range                                       |
   //+------------------------------------------------------------------+
   void ConfigureAdjustmentRange(double minimumAdjustment, double maximumAdjustment)
   {
      m_minimumAdjustment = MathMax(0.1, MathMin(1.0, minimumAdjustment));  // Ensure between 10-100%
      m_maximumAdjustment = MathMax(m_minimumAdjustment, MathMin(1.0, maximumAdjustment)); // Ensure valid range
      
      if(m_logger != NULL)
      {
         Log.Info("Risk adjustment range updated: " + 
                  DoubleToString(m_minimumAdjustment * 100, 1) + "%-" + 
                  DoubleToString(m_maximumAdjustment * 100, 1) + "%");
      }
   }
   
   //+------------------------------------------------------------------+
   //| Set the metric name to use for risk adjustment                   |
   //+------------------------------------------------------------------+
   void SetMetricName(string metricName)
   {
      if(metricName != "")
      {
         m_metricName = metricName;
         
         if(m_logger != NULL)
         {
            Log.Info("Risk adjustment metric changed to: " + metricName);
         }
      }
   }
   
   //+------------------------------------------------------------------+
   //| Check if health-based risk adjustment is active                  |
   //+------------------------------------------------------------------+
   bool IsActive()
   {
      return m_useHealthBasedRisk && m_enforceHealthChecks && m_healthMonitor != NULL;
   }
};