package UnattendedGroundSensorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    enum def TargetClassification {
        personnel;
        lightVehicle;
        heavyVehicle;
        animal;
        unknown;
    }
    
    enum def ConfidenceLevel {
        low;
        medium;
        high;
    }
    
    enum def SeverityLevel {
        minor;
        moderate;
        critical;
    }
    
    enum def BatteryStatus {
        full;
        good;
        low;
        critical;
    }
    
    attribute def VibrationType :> Real;
    attribute def SoundSignature :> Real;
    attribute def HeatSignature :> Real;
    attribute def MagneticSignature :> Real;
    attribute def DataStorageValue :> Real;
    
    attribute def AlertData {
        attribute timestamp : DurationValue;
        attribute location : String;
        attribute targetType : TargetClassification;
        attribute confidence : ConfidenceLevel;
        attribute severity : SeverityLevel;
    }
    
    attribute def SigDetectionEvent;
    attribute def SigHighConfidence;
    attribute def SigLowPower;
    attribute def SigActivate;
    attribute def SigStandby;
    attribute def SigLowPowerMode;
    attribute def SigChargeLow;
    attribute def SigChargeGood;
    
    port def SensorDataPort {
        out attribute data : Real;
    }
    
    port def ProcessorInputPort {
        in attribute seismicData : VibrationType;
        in attribute acousticData : SoundSignature;
        in attribute pirData : HeatSignature;
        in attribute magneticData : MagneticSignature;
    }
    
    port def AlertPort {
        out attribute alert : AlertData;
    }
    
    port def PowerStatusPort {
        out attribute status : BatteryStatus;
        out attribute chargeLevel : Real;
    }
    
    port def NetworkPort {
        out attribute transmitData : AlertData;
        in attribute receiveData : AlertData;
    }
    
    part def SeismicSensor {
        port dataOut : SensorDataPort;
        attribute sensitivity : Real;
        perform action detectVibration {
            out vibrationLevel : VibrationType;
            first start;
            then action senseGroundMovement;
            then action filterNoise;
            then action outputSignal;
            then done;
        }
    }
    
    part def AcousticSensor {
        port dataOut : SensorDataPort;
        attribute frequencyRange : Real;
        perform action detectSound {
            out soundLevel : SoundSignature;
            first start;
            then action captureAudio;
            then action analyzeFrequency;
            then action extractSignature;
            then done;
        }
    }
    
    part def PIRSensor {
        port dataOut : SensorDataPort;
        attribute detectionRange : LengthValue;
        perform action detectHeat {
            out heatLevel : HeatSignature;
            first start;
            then action senseInfrared;
            then action detectMotion;
            then action calculateHeatSignature;
            then done;
        }
    }
    
    part def MagneticSensor {
        port dataOut : SensorDataPort;
        attribute magneticSensitivity : Real;
        perform action detectMetal {
            out magneticLevel : MagneticSignature;
            first start;
            then action measureMagneticField;
            then action detectAnomaly;
            then action quantifySignature;
            then done;
        }
    }
    
    part def SignalProcessor {
        port sensorInputs : ProcessorInputPort;
        port alertOutput : AlertPort;
        attribute processingPower : PowerValue;
        
        perform action fuseSensorData {
            in seismicInput : VibrationType;
            in acousticInput : SoundSignature;
            in pirInput : HeatSignature;
            in magneticInput : MagneticSignature;
            out classification : TargetClassification;
            out confidence : ConfidenceLevel;
            
            first start;
            then action collectSensorData;
            then action normalizeData;
            then action correlateSignatures;
            then action applyClassificationAlgorithm;
            then action calculateConfidence;
            then action determineTargetType;
            then done;
        }
        
        perform action generateAlert {
            in targetType : TargetClassification;
            in confidenceLevel : ConfidenceLevel;
            out alertData : AlertData;
            first start;
            then action captureTimestamp;
            then action determineLocation;
            then action calculateSeverity;
            then action packageAlertData;
            then done;
        }
        
        state processingStates {
            entry; then idle;
            
            state idle;
            accept SigDetectionEvent
                do fuseSensorData
                then analyzing;
            
            state analyzing;
            accept SigHighConfidence
                do generateAlert
                then alertReady;
            accept when fuseSensorData.confidence != ConfidenceLevel::high
                then idle;
            
            state alertReady;
            then idle;
        }
    }
    
    part def CommunicationModule {
        port networkInterface : NetworkPort;
        attribute networkID : String;
        attribute transmitPower : PowerValue;
        attribute meshProtocol : String;
        
        perform action transmitAlert {
            in alert : AlertData;
            first start;
            then action encryptData;
            then action formMeshPacket;
            then action transmitOverRF;
            then action confirmTransmission;
            then done;
        }
        
        perform action receiveData {
            in networkData : AlertData;
        }
    }
    
    part def DataLogger {
        attribute storageCapacity : DataStorageValue;
        attribute currentStorage : DataStorageValue;
        
        perform action logData {
            in dataToLog : AlertData;
            first start;
            then action formatLogEntry;
            then action writeToMemory;
            then action updateIndex;
            then done;
        }
        
        perform action retrieveData {
            out historicalData : AlertData[*];
        }
    }
    
    part def Battery {
        attribute capacity : EnergyValue;
        attribute currentCharge : Real;
        attribute voltage : ElectricPotentialValue;
        port statusPort : PowerStatusPort;
        
        perform action reportStatus {
            out status : BatteryStatus;
            out level : Real;
            first start;
            then action measureVoltage;
            then action calculateCharge;
            then action determineBatteryStatus;
            then done;
        }
        
        perform action dischargeEnergy {
            in powerDraw : PowerValue;
        }
    }
    
    part def SolarPanel {
        attribute outputPower : PowerValue;
        attribute surfaceArea : AreaValue;
        attribute efficiency : Real;
        
        perform action chargeBatterySolar {
            in solarIrradiance : PowerValue;
            out generatedPower : PowerValue;
            first start;
            then action convertSolarEnergy;
            then action regulateVoltage;
            then action deliverPower;
            then done;
        }
    }
    
    part def PowerManagementUnit {
        port batteryMonitor : PowerStatusPort;
        
        perform action managePower {
            in batteryStatus : BatteryStatus;
            in chargeLevel : Real;
            out operatingMode : String;
            
            first start;
            then action checkBatteryLevel;
            then action assessSolarInput;
            then action determinePowerMode;
            then action adjustComponentPower;
            then action issueControlSignals;
            then done;
        }
    }
    
    part def SensorNode {
        attribute nodeID : String;
        attribute deploymentDuration : DurationValue;
        attribute gpsLocation : String;
        
        part seismicSensor : SeismicSensor;
        part acousticSensor : AcousticSensor;
        part pirSensor : PIRSensor;
        part magneticSensor : MagneticSensor;
        part processor : SignalProcessor;
        part commModule : CommunicationModule;
        part logger : DataLogger;
        part powerMgmt : PowerManagementUnit;
        part battery : Battery;
        part solarPanel : SolarPanel;
        
        connect seismicSensor.dataOut to processor.sensorInputs;
        connect acousticSensor.dataOut to processor.sensorInputs;
        connect pirSensor.dataOut to processor.sensorInputs;
        connect magneticSensor.dataOut to processor.sensorInputs;
        connect processor.alertOutput to commModule.networkInterface;
        connect processor.alertOutput to logger;
        connect battery.statusPort to powerMgmt.batteryMonitor;
        connect solarPanel to battery;
        connect battery to powerMgmt;
        connect powerMgmt to seismicSensor;
        connect powerMgmt to acousticSensor;
        connect powerMgmt to pirSensor;
        connect powerMgmt to magneticSensor;
        connect powerMgmt to processor;
        connect powerMgmt to commModule;
        connect powerMgmt to logger;
        
        message alertGenerated of SigHighConfidence from processor to commModule;
        message lowPowerWarning of SigLowPower from powerMgmt to processor;
        
        state nodeOperationalStates parallel {
            state surveillanceMode {
                entry; then standby;
                
                state standby {
                    do action minimalSurveillance;
                }
                accept SigActivate
                    then activeSurveillance;
                
                state activeSurveillance {
                    state monitoring {
                        do action collectAllSensorData {
                            first start;
                            then seismicSensor.detectVibration;
                            then acousticSensor.detectSound;
                            then pirSensor.detectHeat;
                            then magneticSensor.detectMetal;
                            then done;
                        }
                    }
                    
                    accept SigDetectionEvent
                        do send new SigDetectionEvent() to processor
                        then processing;
                    
                    state processing {
                        do processor.fuseSensorData;
                    }
                    accept SigHighConfidence
                        then alerting;
                    accept when processor.fuseSensorData.confidence != ConfidenceLevel::high
                        then monitoring;
                    
                    state alerting {
                        do action transmitAndLogAlert {
                            first start;
                            then processor.generateAlert;
                            then commModule.transmitAlert;
                            then logger.logData;
                            then done;
                        }
                    }
                    then monitoring;
                }
                
                accept SigStandby
                    then standby;
                accept SigLowPowerMode
                    then lowPowerMode;
                
                state lowPowerMode {
                    do action reducedOperations {
                        first start;
                        then action reducedSurveillance;
                        then action periodicWakeup;
                        then done;
                    }
                }
                accept SigActivate
                    then activeSurveillance;
            }
            
            state powerMode {
                entry; then normalPower;
                
                state normalPower {
                    do action normalPowerOperations {
                        first start;
                        then powerMgmt.managePower;
                        then solarPanel.chargeBatterySolar;
                        then battery.reportStatus;
                        then done;
                    }
                }
                accept when battery.currentCharge < 0.3
                    then powerSaving;
                
                state powerSaving {
                    do action powerSavingOperations {
                        first start;
                        then powerMgmt.managePower;
                        then solarPanel.chargeBatterySolar;
                        then done;
                    }
                }
                accept when battery.currentCharge > 0.7
                    then normalPower;
                accept when battery.currentCharge < 0.1
                    then criticalPower;
                
                state criticalPower {
                    do action criticalPowerOperations {
                        first start;
                        then action minimizePowerConsumption;
                        then solarPanel.chargeBatterySolar;
                        then done;
                    }
                }
                accept when battery.currentCharge > 0.3
                    then powerSaving;
            }
        }
    }
    
    part def CommandCenter {
        port meshNetworkInterface : NetworkPort;
        attribute centerID : String;
        
        part alertReceiver {
            perform action receiveAlert {
                in alert : AlertData;
                first start;
                then action validateAlert;
                then action timestampReceipt;
                then action forwardToDisplay;
                then done;
            }
        }
        
        part displaySystem {
            perform action displayAlert {
                in alert : AlertData;
                first start;
                then action renderOnMap;
                then action highlightThreat;
                then action updateTacticalDisplay;
                then done;
            }
        }
        
        part analysisStation {
            perform action analyzeThreats {
                in alerts : AlertData[*];
                first start;
                then action correlateThreatPatterns;
                then action assessThreatLevel;
                then action generateTacticalReport;
                then done;
            }
        }
        
        part dataArchive {
            perform action archiveAlerts {
                in alert : AlertData;
            }
        }
        
        connect meshNetworkInterface to alertReceiver;
        connect alertReceiver to displaySystem;
        connect alertReceiver to analysisStation;
        connect alertReceiver to dataArchive;
        
        state commandCenterStates {
            entry; then operational;
            
            state operational {
                do action processAllAlerts {
                    first start;
                    then alertReceiver.receiveAlert;
                    then displaySystem.displayAlert;
                    then analysisStation.analyzeThreats;
                    then done;
                }
            }
        }
    }
    
    part ugsSystem {
        part sensorNodes : SensorNode[4..100];
        part commandCenter : CommandCenter;
        
        connect sensorNodes.commModule.networkInterface to commandCenter.meshNetworkInterface;
    }
    
    requirement def AutonomousOperationRequirement {
        doc /* The sensor node shall operate autonomously for at least 90 days without maintenance when equipped with solar charging. */
        subject node : SensorNode;
        require constraint {
            node.deploymentDuration >= 90 [d]
        }
    }
    
    requirement def MultiSensorFusionRequirement {
        doc /* The sensor node shall fuse data from all four sensor types for target classification. */
        subject node : SensorNode;
    }
    
    requirement def HighConfidenceAlertRequirement {
        doc /* Alerts shall only be transmitted when confidence level is HIGH. */
        subject proc : SignalProcessor;
        require constraint {
            proc.fuseSensorData.confidence == ConfidenceLevel::high
        }
    }
    
    requirement def TargetClassificationRequirement {
        doc /* The system shall classify detected targets into categories. */
        subject proc : SignalProcessor;
    }
    
    requirement def MeshNetworkRequirement {
        doc /* Sensor nodes shall communicate via secure RF mesh network. */
        subject comm : CommunicationModule;
    }
    
    requirement def PowerManagementRequirement {
        doc /* Power management unit shall adjust operating modes based on battery levels. */
        subject pmu : PowerManagementUnit;
    }
    
    requirement def DataLoggingRequirement {
        doc /* All alerts shall be logged locally. */
        subject logger : DataLogger;
    }
}
