package DewWarningSystem {
    import ISQ::TemperatureValue;
    import ISQ::TemperatureDifferenceValue;
    
    // ---- Value types with units ----
    item def Temperature :> ScalarValues::Real {
        :> TemperatureValue;
        private attribute unit = "degC";
    }
    
    item def RelativeHumidity :> ScalarValues::Real {
        attribute unit = "percent";
        doc /* Relative humidity in percent, range 0..100. */
    }
    
    item def TemperatureDifference :> ScalarValues::Real {
        :> TemperatureDifferenceValue;
        private attribute unit = "K";
    }
    
    // ---- Enumerations ----
    enum def RiskLevel {
        safe;
        caution;
        warning;
        critical;
    }
    
    // ---- Item definitions ----
    item def AmbientData {
        attribute airTemp : Temperature;
        attribute relHumidity : RelativeHumidity;
    }
    
    item def SurfaceData {
        attribute surfaceTemp : Temperature;
    }
    
    item def DewPointData {
        attribute dewPoint : Temperature;
    }
    
    item def RiskAssessment {
        attribute level : RiskLevel;
        attribute margin : TemperatureDifference;
    }
    
    item def AlertMessage {
        attribute level : RiskLevel;
        attribute text : String;
    }
    
    // ---- Port definitions ----
    port def AmbientOutPort { out ambientData : AmbientData; }
    port def SurfaceOutPort { out surfaceData : SurfaceData; }
    port def AmbientInPort { in ambientData : AmbientData; }
    port def SurfaceInPort { in surfaceData : SurfaceData; }
    port def DewPointOutPort { out dewPointData : DewPointData; }
    port def DewPointInPort { in dewPointData : DewPointData; }
    port def SurfaceTempInPort { in surfaceData : SurfaceData; }
    port def RiskOutPort { out riskAssessment : RiskAssessment; }
    port def RiskInPort { in riskAssessment : RiskAssessment; }
    port def AlertOutPort { out alertMessage : AlertMessage; }
    port def AlertInPort { in alertMessage : AlertMessage; }
    
    // ---- Component part definitions ----
    part def AmbientSensor {
        port ambientOut : AmbientOutPort;
        
        attribute samplingPeriod : Time = 1 [s];
        
        attribute currentAirTemp : Temperature = 20.0;
        attribute currentRelHumidity : RelativeHumidity = 50.0;
        
        action measureAmbient {
            out airTemp : Temperature = currentAirTemp;
            out relHumidity : RelativeHumidity = currentRelHumidity;
        }
        
        state ambientSensorBehavior {
            entry; then measuring;
            state measuring {
                do send AmbientData(airTemp => currentAirTemp, relHumidity => currentRelHumidity) via ambientOut.ambientData;
            }
        }
    }
    
    part def SurfaceSensor {
        port surfaceOut : SurfaceOutPort;
        
        attribute samplingPeriod : Time = 1 [s];
        attribute currentSurfaceTemp : Temperature = 18.0;
        
        action measureSurface {
            out surfaceTemp : Temperature = currentSurfaceTemp;
        }
        
        state surfaceSensorBehavior {
            entry; then measuring;
            state measuring {
                do send SurfaceData(surfaceTemp => currentSurfaceTemp) via surfaceOut.surfaceData;
            }
        }
    }
    
    part def DewPointProcessor {
        port ambientIn : AmbientInPort;
        port dewPointOut : DewPointOutPort;
        
        // Magnus formula constants
        attribute a : Real = 17.625;
        attribute b : Real = 243.04;
        
        attribute lastDewPoint : Temperature;
        
        action calculateDewPoint {
            in airTemp : Temperature;
            in relHumidity : RelativeHumidity;
            return dewPoint : Temperature;
            
            // Magnus formula:
            // alpha = (a * T) / (b + T) + ln(RH/100)
            // Tdp = (b * alpha) / (a - alpha)
            private attribute alpha : Real = (a * airTemp) / (b + airTemp) + Math::ln(relHumidity / 100.0);
            return dewPoint = (b * alpha) / (a - alpha);
        }
        
        state dewPointBehavior {
            entry; then idle;
            state idle {
                on ambientData via ambientIn.ambientData do {
                    lastDewPoint = calculateDewPoint(airTemp => ambientData.airTemp, relHumidity => ambientData.relHumidity);
                    send DewPointData(dewPoint => lastDewPoint) via dewPointOut.dewPointData;
                }
            }
        }
    }
    
    part def RiskAnalyzer {
        port dewPointIn : DewPointInPort;
        port surfaceTempIn : SurfaceTempInPort;
        port riskOut : RiskOutPort;
        
        // Thresholds (surface temp - dew point)
        attribute cautionThreshold : TemperatureDifference = 5.0;
        attribute warningThreshold : TemperatureDifference = 3.0;
        attribute criticalThreshold : TemperatureDifference = 1.0;
        
        attribute currentRisk : RiskLevel = RiskLevel::safe;
        attribute currentMargin : TemperatureDifference;
        
        action assessRisk {
            in surfaceTemp : Temperature;
            in dewPoint : Temperature;
            return level : RiskLevel;
            return margin : TemperatureDifference;
            
            attribute diff : TemperatureDifference = surfaceTemp - dewPoint;
            
            if diff > cautionThreshold {
                return level = RiskLevel::safe;
            } else if diff > warningThreshold {
                return level = RiskLevel::caution;
            } else if diff > criticalThreshold {
                return level = RiskLevel::warning;
            } else {
                return level = RiskLevel::critical;
            }
            return margin = diff;
        }
        
        state riskAnalyzerBehavior {
            entry; then monitoring;
            state monitoring {
                on dewPointData via dewPointIn.dewPointData do {
                    // store latest dew point
                }
                on surfaceData via surfaceTempIn.surfaceData do {
                    attribute dp : Temperature = dewPointData.dewPoint;
                    attribute st : Temperature = surfaceData.surfaceTemp;
                    currentRisk = assessRisk(surfaceTemp => st, dewPoint => dp).level;
                    currentMargin = assessRisk(surfaceTemp => st, dewPoint => dp).margin;
                    send RiskAssessment(level => currentRisk, margin => currentMargin) via riskOut.riskAssessment;
                }
            }
        }
    }
    
    part def AlertGenerator {
        port riskIn : RiskInPort;
        port alertOut : AlertOutPort;
        
        action generateAlert {
            in level : RiskLevel;
            return message : AlertMessage;
            
            if level == RiskLevel::safe {
                return message = AlertMessage(level => RiskLevel::safe, text => "Conditions safe: no dew risk.");
            } else if level == RiskLevel::caution {
                return message = AlertMessage(level => RiskLevel::caution, text => "Caution: dew formation becoming possible.");
            } else if level == RiskLevel::warning {
                return message = AlertMessage(level => RiskLevel::warning, text => "Warning: high risk of condensation.");
            } else {
                return message = AlertMessage(level => RiskLevel::critical, text => "CRITICAL: dew formation imminent!");
            }
        }
        
        state alertGeneratorBehavior {
            entry; then idle;
            state idle {
                on riskAssessment via riskIn.riskAssessment do {
                    attribute msg : AlertMessage = generateAlert(level => riskAssessment.level);
                    send msg via alertOut.alertMessage;
                }
            }
        }
    }
    
    part def VisualIndicator {
        port alertIn : AlertInPort;
        
        attribute displayText : String = "System initialized";
        attribute displayLevel : RiskLevel = RiskLevel::safe;
        
        state indicatorBehavior {
            entry; then idle;
            state idle {
                on alertMessage via alertIn.alertMessage do {
                    displayLevel = alertMessage.level;
                    displayText = alertMessage.text;
                }
            }
        }
    }
    
    // ---- Top-level system ----
    part def DewWarningSystem {
        part ambientSensor : AmbientSensor;
        part surfaceSensor : SurfaceSensor;
        part dewPointProcessor : DewPointProcessor;
        part riskAnalyzer : RiskAnalyzer;
        part alertGenerator : AlertGenerator;
        part visualIndicator : VisualIndicator;
        
        connection ambientSensor.ambientOut to dewPointProcessor.ambientIn;
        connection surfaceSensor.surfaceOut to riskAnalyzer.surfaceTempIn;
        connection dewPointProcessor.dewPointOut to riskAnalyzer.dewPointIn;
        connection riskAnalyzer.riskOut to alertGenerator.riskIn;
        connection alertGenerator.alertOut to visualIndicator.alertIn;
    }
    
    // ---- Requirements ----
    requirement def MonitorAmbientConditions {
        subject : DewWarningSystem;
        objective {
            doc /* The system shall continuously measure ambient air temperature and relative humidity. */
            assert ambientSensor.currentAirTemp != null;
            assert ambientSensor.currentRelHumidity >= 0.0 and ambientSensor.currentRelHumidity <= 100.0;
        }
    }
    
    requirement def MonitorSurfaceTemperature {
        subject : DewWarningSystem;
        objective {
            doc /* The system shall continuously measure the temperature of the protected surface. */
            assert surfaceSensor.currentSurfaceTemp != null;
        }
    }
    
    requirement def CalculateDewPoint {
        subject : DewWarningSystem;
        objective {
            doc /* The system shall calculate the dew point from ambient temperature and relative humidity. */
            assert dewPointProcessor.lastDewPoint != null;
        }
    }
    
    requirement def AssessRiskLevel {
        subject : DewWarningSystem;
        objective {
            doc /* The system shall classify risk into safe, caution, warning, or critical based on surface temperature minus dew point. */
            assert riskAnalyzer.currentRisk in RiskLevel;
        }
    }
    
    requirement def ProvideGraduatedAlerts {
        subject : DewWarningSystem;
        objective {
            doc /* The system shall provide a four-tier alert with a clear text message to the visual indicator. */
            assert visualIndicator.displayLevel in RiskLevel;
            assert visualIndicator.displayText != "";
        }
    }
    
    requirement def AlertThresholds {
        subject : DewWarningSystem;
        objective {
            doc /* Thresholds: safe > 5K, caution 3-5K, warning 1-3K, critical <= 1K. */
            assert riskAnalyzer.cautionThreshold == 5.0;
            assert riskAnalyzer.warningThreshold == 3.0;
            assert riskAnalyzer.criticalThreshold == 1.0;
        }
    }
    
    requirement def DewWarningSystemRequirement {
        subject : DewWarningSystem;
        satisfy MonitorAmbientConditions;
        satisfy MonitorSurfaceTemperature;
        satisfy CalculateDewPoint;
        satisfy AssessRiskLevel;
        satisfy ProvideGraduatedAlerts;
        satisfy AlertThresholds;
        
        doc /* The Dew Warning System shall monitor environmental conditions and prevent condensation damage by alerting operators before moisture forms on a protected surface. */
    }
    
    // ---- Instantiation ----
    part systemInstance : DewWarningSystem {
        satisfy DewWarningSystemRequirement;
    }
}
