package ContinuousGlucoseMonitoringSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def GlucoseConcentration :> Real {
        doc /* Glucose concentration measured in milligrams per deciliter */
    }
    
    enum def TrendDirection {
        rapidlyRising;
        rising;
        steady;
        falling;
        rapidlyFalling;
    }
    
    enum def AlertType {
        none;
        lowGlucose;
        highGlucose;
        criticalLow;
        criticalHigh;
        sensorError;
    }
    
    attribute def GlucoseTrend {
        attribute direction : TrendDirection;
        attribute rateOfChange : Real;
    }
    
    item def GlucoseReading {
        attribute concentration : GlucoseConcentration;
        attribute timestamp : TimeValue;
        attribute trend : GlucoseTrend;
        attribute isValid : Boolean;
    }
    
    item def CalibrationData {
        attribute referenceValue : GlucoseConcentration;
        attribute timestamp : TimeValue;
    }
    
    item def AlertMessage {
        attribute alertType : AlertType;
        attribute glucoseValue : GlucoseConcentration;
        attribute timestamp : TimeValue;
    }
    
    port def SensorDataPort {
        out glucoseReading : GlucoseReading;
        out sensorStatus : Boolean;
    }
    
    port def WirelessDataPort {
        in transmitData : GlucoseReading;
        out receiveData : GlucoseReading;
    }
    
    port def DisplayInterfacePort {
        in currentReading : GlucoseReading;
        in alertSignal : AlertMessage;
        out displayStatus : Boolean;
    }
    
    port def UserInterfacePort {
        in calibrationInput : CalibrationData;
        in userSettings : Real;
        out acknowledgment : Boolean;
    }
    
    part def SubcutaneousSensor {
        doc /* Electrochemical sensor implanted subcutaneously to measure interstitial glucose */
        
        attribute sensorLifetime : TimeValue = 10.0[SI::d];
        attribute warmUpTime : TimeValue = 2.0[SI::h];
        attribute samplingRate : TimeValue = 5.0[SI::min];
        attribute measurementAccuracy : Real = 0.92;
        
        port sensorOutput : SensorDataPort;
        
        action def MeasureInterstitialGlucose {
            in enzymaticReaction : Real;
            out rawSignal : Real;
            out glucoseConcentration : GlucoseConcentration;
            out measurementValid : Boolean;
        }
        
        action def PerformSelfDiagnostic {
            out sensorIntegrity : Boolean;
            out signalQuality : Real;
        }
    }
    
    part def WirelessTransmitter {
        doc /* Transmitter attached to sensor that sends data wirelessly to receiver */
        
        attribute batteryCapacity : Real = 100.0;
        attribute transmissionPower : Real;
        attribute transmissionRange : LengthValue = 6.0[SI::m];
        attribute dataRate : Real;
        
        port sensorInterface : ~SensorDataPort;
        port wirelessOutput : WirelessDataPort;
        
        action def EncodeData {
            in sensorReading : GlucoseReading;
            out encodedPacket : GlucoseReading;
        }
        
        action def TransmitWireless {
            in dataPacket : GlucoseReading;
            out transmissionSuccess : Boolean;
        }
        
        action def MonitorBattery {
            out batteryLevel : Real;
            out lowBatteryWarning : Boolean;
        }
    }
    
    part def ReceiverDisplay {
        doc /* Handheld receiver that displays glucose readings and trends */
        
        attribute displaySize : LengthValue = 0.08[SI::m];
        attribute dataStorageDays : Real = 90.0;
        attribute screenBrightness : Real;
        
        port wirelessInput : ~WirelessDataPort;
        port displayInterface : DisplayInterfacePort;
        port userInterface : UserInterfacePort;
        
        action def ReceiveWirelessData {
            out receivedReading : GlucoseReading;
            out signalStrength : Real;
        }
        
        action def UpdateDisplay {
            in currentData : GlucoseReading;
            in alertData : AlertMessage;
            out displayRefreshed : Boolean;
        }
        
        action def StoreHistoricalData {
            in reading : GlucoseReading;
            out storageSuccess : Boolean;
        }
    }
    
    part def DataAnalysisProcessor {
        doc /* Processes glucose data to calculate trends and filter noise */
        
        attribute trendCalculationWindow : TimeValue = 15.0[SI::min];
        attribute filterCoefficient : Real = 0.85;
        attribute historicalReadings : GlucoseReading[*];
        
        action def ApplyKalmanFilter {
            in rawReading : GlucoseConcentration;
            in previousEstimate : GlucoseConcentration;
            out filteredReading : GlucoseConcentration;
        }
        
        action def CalculateGlucoseTrend {
            in recentReadings : GlucoseReading[*];
            in timeWindow : TimeValue;
            out trend : GlucoseTrend;
        }
        
        action def PredictFutureGlucose {
            in currentTrend : GlucoseTrend;
            in currentLevel : GlucoseConcentration;
            in predictionHorizon : TimeValue;
            out predictedLevel : GlucoseConcentration;
        }
    }
    
    part def AlertManagementSystem {
        doc /* Monitors glucose levels and generates appropriate alerts */
        
        attribute hypoglycemiaThreshold : GlucoseConcentration = 70.0;
        attribute hyperglycemiaThreshold : GlucoseConcentration = 180.0;
        attribute criticalLowThreshold : GlucoseConcentration = 54.0;
        attribute criticalHighThreshold : GlucoseConcentration = 250.0;
        attribute alertSnoozeTime : TimeValue = 30.0[SI::min];
        
        action def EvaluateGlucoseLevel {
            in currentLevel : GlucoseConcentration;
            in currentTrend : GlucoseTrend;
            in predictedLevel : GlucoseConcentration;
            out alertRequired : AlertType;
        }
        
        action def GenerateAlert {
            in alertType : AlertType;
            in glucoseValue : GlucoseConcentration;
            out alertMessage : AlertMessage;
            out audioAlert : Boolean;
            out vibrationAlert : Boolean;
        }
        
        action def ManageAlertEscalation {
            in persistentCondition : Boolean;
            in timeInCondition : TimeValue;
            out escalatedAlert : Boolean;
        }
    }
    
    part def CalibrationManager {
        doc /* Manages sensor calibration using fingerstick blood glucose references */
        
        attribute calibrationFrequency : TimeValue = 12.0[SI::h];
        attribute calibrationHistory : CalibrationData[*];
        attribute calibrationAccuracy : Real;
        
        action def RequestCalibration {
            out calibrationPrompt : Boolean;
            out recommendedTime : TimeValue;
        }
        
        action def ProcessCalibration {
            in referenceValue : GlucoseConcentration;
            in sensorValue : GlucoseConcentration;
            out calibrationFactor : Real;
            out calibrationSuccess : Boolean;
        }
        
        action def ValidateCalibration {
            in calibrationFactor : Real;
            in historicalFactors : Real[*];
            out factorValid : Boolean;
        }
    }
    
    part def ContinuousGlucoseMonitor {
        doc /* Integrated continuous glucose monitoring system */
        
        part sensor : SubcutaneousSensor;
        part transmitter : WirelessTransmitter;
        part receiver : ReceiverDisplay;
        part dataProcessor : DataAnalysisProcessor;
        part alertManager : AlertManagementSystem;
        part calibrationMgr : CalibrationManager;
    }
    
    part continuousGlucoseMonitor : ContinuousGlucoseMonitor {
        doc /* Complete CGM system providing continuous real-time glucose monitoring */
        
        part sensor : SubcutaneousSensor {
            :>> sensorLifetime = 10.0[SI::d];
            :>> samplingRate = 5.0[SI::min];
            :>> measurementAccuracy = 0.92;
        }
        
        part transmitter : WirelessTransmitter {
            :>> batteryCapacity = 100.0;
            :>> transmissionRange = 6.0[SI::m];
        }
        
        part receiver : ReceiverDisplay {
            :>> displaySize = 0.08[SI::m];
            :>> dataStorageDays = 90.0;
        }
        
        part dataProcessor : DataAnalysisProcessor {
            :>> trendCalculationWindow = 15.0[SI::min];
            :>> filterCoefficient = 0.85;
        }
        
        part alertManager : AlertManagementSystem {
            :>> hypoglycemiaThreshold = 70.0;
            :>> hyperglycemiaThreshold = 180.0;
            :>> criticalLowThreshold = 54.0;
            :>> criticalHighThreshold = 250.0;
        }
        
        part calibrationMgr : CalibrationManager {
            :>> calibrationFrequency = 12.0[SI::h];
        }
        
        connect sensor.sensorOutput to transmitter.sensorInterface;
        connect transmitter.wirelessOutput to receiver.wirelessInput;
        
        perform action monitoringOperation : ContinuousGlucoseMonitoring;
    }
    
    action def ContinuousGlucoseMonitoring {
        in measurementInterval : TimeValue;
        in lowThreshold : GlucoseConcentration;
        in highThreshold : GlucoseConcentration;
        out glucoseHistory : GlucoseReading[*];
        out alertHistory : AlertMessage[*];
        
        first start;
        then merge monitoringCycle;
        
        loop action continuousMonitoring {
            action measureGlucose : SubcutaneousSensor::MeasureInterstitialGlucose {
                out rawSignal;
                out glucoseConcentration;
                out measurementValid;
            }
            
            then if measureGlucose.measurementValid {
                action filterReading : DataAnalysisProcessor::ApplyKalmanFilter {
                    in rawReading = measureGlucose.glucoseConcentration;
                    out filteredReading;
                }
                
                then action calculateTrend : DataAnalysisProcessor::CalculateGlucoseTrend {
                    in recentReadings = glucoseHistory;
                    in timeWindow = measurementInterval;
                    out trend;
                }
                
                then action predictGlucose : DataAnalysisProcessor::PredictFutureGlucose {
                    in currentTrend = calculateTrend.trend;
                    in currentLevel = filterReading.filteredReading;
                    in predictionHorizon = 30.0[SI::min];
                    out predictedLevel;
                }
                
                then action evaluateLevel : AlertManagementSystem::EvaluateGlucoseLevel {
                    in currentLevel = filterReading.filteredReading;
                    in currentTrend = calculateTrend.trend;
                    in predictedLevel = predictGlucose.predictedLevel;
                    out alertRequired;
                }
                
                then decide;
                    if evaluateLevel.alertRequired != AlertType::none then generateAlert;
                    else transmitData;
                
                action generateAlert : AlertManagementSystem::GenerateAlert {
                    in alertType = evaluateLevel.alertRequired;
                    in glucoseValue = filterReading.filteredReading;
                    out alertMessage;
                    out audioAlert;
                    out vibrationAlert;
                }
                then assign alertHistory := alertHistory->append(generateAlert.alertMessage);
                then transmitData;
                
                merge transmitData;
                action encodeData : WirelessTransmitter::EncodeData {
                    in sensorReading : GlucoseReading {
                        :>> concentration = filterReading.filteredReading;
                        :>> trend = calculateTrend.trend;
                        :>> isValid = measureGlucose.measurementValid;
                    }
                    out encodedPacket;
                }
                
                then action transmitWireless : WirelessTransmitter::TransmitWireless {
                    in dataPacket = encodeData.encodedPacket;
                    out transmissionSuccess;
                }
                
                then action receiveData : ReceiverDisplay::ReceiveWirelessData {
                    out receivedReading;
                    out signalStrength;
                }
                
                then action updateDisplay : ReceiverDisplay::UpdateDisplay {
                    in currentData = receiveData.receivedReading;
                    out displayRefreshed;
                }
                
                then action storeData : ReceiverDisplay::StoreHistoricalData {
                    in reading = receiveData.receivedReading;
                    out storageSuccess;
                }
                
                then assign glucoseHistory := glucoseHistory->append(receiveData.receivedReading);
            }
        } until false;
        
        then done;
    }
    
    requirement def <'CGM-REQ-001'> ContinuousMonitoringRequirement {
        doc /* The CGM system shall continuously measure interstitial glucose levels at regular intervals not exceeding 5 minutes */
        
        subject cgmSystem : ContinuousGlucoseMonitor;
        
        require constraint {
            cgmSystem.sensor.samplingRate <= 5.0[SI::min]
        }
    }
    
    requirement def <'CGM-REQ-002'> MeasurementAccuracyRequirement {
        doc /* The CGM system shall maintain measurement accuracy of at least 90% correlation with reference blood glucose measurements */
        
        subject cgmSystem : ContinuousGlucoseMonitor;
        
        require constraint {
            cgmSystem.sensor.measurementAccuracy >= 0.90
        }
    }
    
    requirement def <'CGM-REQ-003'> HypoglycemiaAlertRequirement {
        doc /* The CGM system shall generate an alert when glucose levels fall below 70 mg/dL or are predicted to fall below this threshold within 30 minutes */
        
        subject alertSys : AlertManagementSystem;
        
        require constraint {
            alertSys.hypoglycemiaThreshold == 70.0
        }
    }
    
    requirement def <'CGM-REQ-004'> HyperglycemiaAlertRequirement {
        doc /* The CGM system shall generate an alert when glucose levels exceed 180 mg/dL */
        
        subject alertSys : AlertManagementSystem;
        
        require constraint {
            alertSys.hyperglycemiaThreshold == 180.0
        }
    }
    
    requirement def <'CGM-REQ-005'> WirelessRangeRequirement {
        doc /* The CGM transmitter shall maintain reliable wireless communication with the receiver at distances up to 6 meters */
        
        subject trans : WirelessTransmitter;
        
        require constraint {
            trans.transmissionRange >= 6.0[SI::m]
        }
    }
    
    requirement def <'CGM-REQ-006'> DataStorageRequirement {
        doc /* The CGM receiver shall store at least 90 days of continuous glucose data */
        
        subject recv : ReceiverDisplay;
        
        require constraint {
            recv.dataStorageDays >= 90.0
        }
    }
    
    requirement def <'CGM-REQ-007'> SensorLifetimeRequirement {
        doc /* The CGM sensor shall maintain accurate measurements for at least 10 days of continuous use */
        
        subject sens : SubcutaneousSensor;
        
        require constraint {
            sens.sensorLifetime >= 10.0[SI::d]
        }
    }
    
    requirement def <'CGM-REQ-008'> CalibrationRequirement {
        doc /* The CGM system shall require calibration with fingerstick blood glucose measurements at intervals not exceeding 12 hours */
        
        subject calMgr : CalibrationManager;
        
        require constraint {
            calMgr.calibrationFrequency <= 12.0[SI::h]
        }
    }
    
    requirement cgmSystemRequirements {
        doc /* Top-level requirements for continuous glucose monitoring system functionality, accuracy, and safety */
        
        subject continuousGlucoseMonitor;
        
        require continuousMonitoringReq : ContinuousMonitoringRequirement;
        require measurementAccuracyReq : MeasurementAccuracyRequirement;
        require hypoglycemiaAlertReq : HypoglycemiaAlertRequirement;
        require hyperglycemiaAlertReq : HyperglycemiaAlertRequirement;
        require wirelessRangeReq : WirelessRangeRequirement;
        require dataStorageReq : DataStorageRequirement;
        require sensorLifetimeReq : SensorLifetimeRequirement;
        require calibrationReq : CalibrationRequirement;
    }
}
