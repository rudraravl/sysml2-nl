package 'Permanent Downhole Gauge System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SensorData {
        attribute timestamp : Real;
        attribute pressure : PressureValue;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute vibration : AccelerationValue;
        attribute flowRate : VolumeFlowRateValue;
    }
    
    attribute def GaugeStatus {
        attribute operational : Boolean;
        attribute batteryLevel : Real;
        attribute signalQuality : Real;
        attribute lastCalibration : Real;
    }
    
    attribute def TransmissionPacket {
        attribute data : SensorData;
        attribute checksum : Integer;
        attribute sequenceNumber : Integer;
    }
    
    port def SensorOutputPort {
        out sensorData : SensorData;
    }
    
    port def DataInputPort {
        in sensorData : SensorData;
    }
    
    port def CommunicationPort {
        out transmissionPacket : TransmissionPacket;
        in commandSignal : String;
    }
    
    port def PowerPort {
        in voltage : ElectricPotentialValue;
        out currentDraw : ElectricCurrentValue;
    }
    
    part def PressureTransducer {
        attribute measurementRange : PressureValue;
        attribute accuracy : Real;
        attribute resolution : PressureValue;
        port dataOut : SensorOutputPort;
        
        action measurePressure {
            in wellborePressure : PressureValue;
            out reading : SensorData;
        }
    }
    
    part def TemperatureTransducer {
        attribute measurementRange : ThermodynamicTemperatureValue;
        attribute accuracy : Real;
        attribute responseTime : TimeValue;
        port dataOut : SensorOutputPort;
        
        action measureTemperature {
            in wellboreTemperature : ThermodynamicTemperatureValue;
            out reading : SensorData;
        }
    }
    
    part def FlowSensor {
        attribute measurementRange : VolumeFlowRateValue;
        attribute accuracy : Real;
        port dataOut : SensorOutputPort;
        
        action measureFlow {
            in fluidFlow : VolumeFlowRateValue;
            out reading : SensorData;
        }
    }
    
    part def AccelerometerSensor {
        attribute sensitivity : AccelerationValue;
        attribute bandwidth : FrequencyValue;
        port dataOut : SensorOutputPort;
        
        action measureVibration {
            out reading : SensorData;
        }
    }
    
    part def DataAcquisitionModule {
        attribute samplingRate : FrequencyValue;
        attribute bufferSize : Integer;
        port pressureInput : DataInputPort;
        port temperatureInput : DataInputPort;
        port flowInput : DataInputPort;
        port vibrationInput : DataInputPort;
        port aggregatedOutput : SensorOutputPort;
        
        action aggregateSensorData {
            in pressureData : SensorData;
            in temperatureData : SensorData;
            in flowData : SensorData;
            in vibrationData : SensorData;
            out combinedData : SensorData;
        }
        
        action validateData {
            in rawData : SensorData;
            out validatedData : SensorData;
            out isValid : Boolean;
        }
    }
    
    part def TelemetryUnit {
        attribute transmissionProtocol : String;
        attribute dataRate : Real;
        port dataInput : DataInputPort;
        port commPort : CommunicationPort;
        
        action encodeData {
            in sensorData : SensorData;
            out packet : TransmissionPacket;
        }
        
        action transmitToSurface {
            in packet : TransmissionPacket;
            out transmitted : Boolean;
        }
        
        action receiveCommands {
            out command : String;
        }
    }
    
    part def BatteryPack {
        attribute capacity : EnergyValue;
        attribute voltage : ElectricPotentialValue;
        attribute remainingCharge : Real;
        port powerOutput : PowerPort;
        
        action supplyPower {
            out voltage : ElectricPotentialValue;
            out current : ElectricCurrentValue;
        }
        
        action monitorCharge {
            out chargeLevel : Real;
            out estimatedLifetime : TimeValue;
        }
    }
    
    part def ProtectiveHousing {
        attribute pressureRating : PressureValue;
        attribute temperatureRating : ThermodynamicTemperatureValue;
        attribute material : String;
        attribute corrosionResistance : String;
        
        action protectInternals {
            in externalPressure : PressureValue;
            in externalTemperature : ThermodynamicTemperatureValue;
            out integrity : Boolean;
        }
    }
    
    part def CalibrationModule {
        attribute lastCalibrationDate : Real;
        attribute calibrationInterval : TimeValue;
        
        action performSelfCalibration {
            out calibrationStatus : Boolean;
            out correctionFactors : Real[*];
        }
        
        action applyCorrections {
            in rawData : SensorData;
            in corrections : Real[*];
            out correctedData : SensorData;
        }
    }
    
    action def MonitorWellboreConditions {
        in samplingInterval : TimeValue;
        out continuousData : SensorData[*];
    }
    
    action def TransmitRealTimeData {
        in data : SensorData;
        out transmissionSuccess : Boolean;
    }
    
    action def PerformDiagnostics {
        in gaugeStatus : GaugeStatus;
        out healthStatus : Boolean;
        out faultCodes : Integer[*];
    }
    
    part permanentDownholeGaugeSystem {
        doc /* 
            A permanent downhole gauge system for continuous, real-time monitoring 
            of wellbore conditions in oil and gas production wells. The system 
            measures critical parameters including pressure, temperature, flow rate, 
            and vibration, transmitting data to surface facilities for production 
            optimization and reservoir management.
        */
        
        part pressureTransducer : PressureTransducer {
            attribute :>> measurementRange = 200000000.0[SI::Pa];
            attribute :>> accuracy = 0.0005;
            attribute :>> resolution = 1000.0[SI::Pa];
        }
        
        part temperatureTransducer : TemperatureTransducer {
            attribute :>> measurementRange = 523.15[SI::K];
            attribute :>> accuracy = 0.1;
            attribute :>> responseTime = 5.0[SI::s];
        }
        
        part flowSensor : FlowSensor {
            attribute :>> measurementRange = 0.01[SI::m^3/SI::s];
            attribute :>> accuracy = 0.02;
        }
        
        part accelerometer : AccelerometerSensor {
            attribute :>> sensitivity = 0.001[SI::m/SI::s^2];
            attribute :>> bandwidth = 1000.0[SI::Hz];
        }
        
        part dataAcquisition : DataAcquisitionModule {
            attribute :>> samplingRate = 10.0[SI::Hz];
            attribute :>> bufferSize = 1000;
        }
        
        part telemetry : TelemetryUnit {
            attribute :>> transmissionProtocol = "Modbus";
            attribute :>> dataRate = 9600.0;
        }
        
        part battery : BatteryPack {
            attribute :>> capacity = 2000000.0[SI::J];
            attribute :>> voltage = 24.0[SI::V];
            attribute :>> remainingCharge = 1.0;
        }
        
        part housing : ProtectiveHousing {
            attribute :>> pressureRating = 200000000.0[SI::Pa];
            attribute :>> temperatureRating = 523.15[SI::K];
            attribute :>> material = "Inconel 625";
            attribute :>> corrosionResistance = "H2S and CO2 resistant";
        }
        
        part calibration : CalibrationModule {
            attribute :>> lastCalibrationDate = 0.0;
            attribute :>> calibrationInterval = 31536000.0[SI::s];
        }
        
        connect pressureTransducer.dataOut to dataAcquisition.pressureInput;
        connect temperatureTransducer.dataOut to dataAcquisition.temperatureInput;
        connect flowSensor.dataOut to dataAcquisition.flowInput;
        connect accelerometer.dataOut to dataAcquisition.vibrationInput;
        connect dataAcquisition.aggregatedOutput to telemetry.dataInput;
        connect battery.powerOutput to dataAcquisition;
        connect battery.powerOutput to telemetry;
        
        perform action continuousWellboreMonitoring {
            doc /* 
                Primary system function: Continuously monitor wellbore conditions 
                and transmit real-time data to surface for production optimization.
            */
            
            first start;
            then action systemInitialization {
                action powerUp {
                    action activateBattery;
                    then action initializeSensors;
                    then action establishCommunication;
                }
                then action performInitialCalibration {
                    action calibratePressure;
                    then action calibrateTemperature;
                    then action calibrateFlow;
                    then action calibrateVibration;
                }
                then action runSelfDiagnostics {
                    out diagnosticsPassed : Boolean;
                }
            }
            then merge monitoringLoop;
            
            action monitoringCycle {
                action acquirePressureData : MonitorWellboreConditions {
                    in samplingInterval : TimeValue;
                    out continuousData : SensorData[*];
                }
                
                flow acquirePressureData.continuousData to acquireTemperatureData.continuousData;
                
                action acquireTemperatureData : MonitorWellboreConditions {
                    in samplingInterval : TimeValue;
                    out continuousData : SensorData[*];
                }
                
                flow acquireTemperatureData.continuousData to acquireFlowData.continuousData;
                
                action acquireFlowData : MonitorWellboreConditions {
                    in samplingInterval : TimeValue;
                    out continuousData : SensorData[*];
                }
                
                flow acquireFlowData.continuousData to acquireVibrationData.continuousData;
                
                action acquireVibrationData : MonitorWellboreConditions {
                    in samplingInterval : TimeValue;
                    out continuousData : SensorData[*];
                }
                
                then action aggregateAllData {
                    in pressureReadings : SensorData[*];
                    in temperatureReadings : SensorData[*];
                    in flowReadings : SensorData[*];
                    in vibrationReadings : SensorData[*];
                    out mergedData : SensorData;
                }
                
                then action applyCalibrationCorrections {
                    in rawData : SensorData;
                    out calibratedData : SensorData;
                }
                
                then action transmitData : TransmitRealTimeData {
                    in data : SensorData;
                    out transmissionSuccess : Boolean;
                }
                
                then action performSystemDiagnostics : PerformDiagnostics {
                    in gaugeStatus : GaugeStatus;
                    out healthStatus : Boolean;
                    out faultCodes : Integer[*];
                }
                
                then decide;
                    if performSystemDiagnostics.healthStatus then monitoringLoop;
                    if !performSystemDiagnostics.healthStatus then handleFault;
                
                action handleFault {
                    action logFaultCodes {
                        in faults : Integer[*];
                    }
                    then action transmitAlarm {
                        in faultData : Integer[*];
                        out alarmSent : Boolean;
                    }
                    then action attemptRecovery {
                        out recovered : Boolean;
                    }
                    then decide;
                        if attemptRecovery.recovered then monitoringLoop;
                        if !attemptRecovery.recovered then enterSafeMode;
                    
                    action enterSafeMode {
                        doc /* Minimal operation mode preserving critical data */
                    }
                }
            }
            
            then monitoringLoop;
        }
        
        state gaugeOperationalStates {
            entry; then initializing;
            
            state initializing {
                entry action powerUpSequence;
                do action selfTest;
            }
            then initializing.selfTest;
            accept testPassed;
            then operational;
            
            state operational {
                entry action beginMonitoring;
                do action continuousDataAcquisition;
            }
            then operational.continuousDataAcquisition;
            accept at criticalFault;
            then fault;
            
            state calibrating {
                entry action pauseMonitoring;
                do action recalibrateSensors;
            }
            
            state powerSaving {
                entry action reduceSamplingRate;
                do action limitedMonitoring;
            }
            
            state fault {
                entry action logFault;
                do action transmitFaultAlert;
            }
            
            state shutdown;
        }
    }
    
    requirement <'PDG-REQ-001'> continuousDataAcquisition {
        doc /* 
            The permanent downhole gauge system shall continuously acquire 
            pressure, temperature, flow rate, and vibration data from the 
            wellbore at a minimum sampling rate of 1 Hz.
        */
        
        subject gauge : permanentDownholeGaugeSystem;
        
        require constraint {
            gauge.dataAcquisition.samplingRate >= 1.0[SI::Hz]
        }
    }
    
    requirement <'PDG-REQ-002'> measurementAccuracy {
        doc /* 
            The system shall provide measurement accuracy within specified 
            tolerances for all monitored parameters.
        */
        
        subject gauge : permanentDownholeGaugeSystem;
        
        require constraint {
            gauge.pressureTransducer.accuracy <= 0.001
        }
        
        require constraint {
            gauge.temperatureTransducer.accuracy <= 0.5
        }
        
        require constraint {
            gauge.flowSensor.accuracy <= 0.02
        }
    }
    
    requirement <'PDG-REQ-003'> realTimeDataTransmission {
        doc /* 
            The system shall transmit acquired data to surface facilities 
            in real-time with transmission latency not exceeding 1 second.
        */
        
        subject gauge : permanentDownholeGaugeSystem;
        
        require constraint {
            gauge.telemetry.dataRate >= 9600.0
        }
    }
    
    requirement <'PDG-REQ-004'> environmentalSurvivability {
        doc /* 
            The gauge shall survive and operate reliably in extreme downhole 
            conditions including pressures up to 200 MPa and temperatures 
            up to 250 degrees Celsius.
        */
        
        subject gauge : permanentDownholeGaugeSystem;
        
        require constraint {
            gauge.housing.pressureRating >= 200000000.0[SI::Pa]
        }
        
        require constraint {
            gauge.housing.temperatureRating >= 523.15[SI::K]
        }
    }
    
    requirement <'PDG-REQ-005'> operationalLifetime {
        doc /* 
            The system shall operate continuously for a minimum of 10 years 
            without requiring intervention or retrieval from the wellbore.
        */
        
        subject gauge : permanentDownholeGaugeSystem;
        
        require constraint {
            gauge.battery.capacity >= 2000000.0[SI::J]
        }
    }
    
    requirement <'PDG-REQ-006'> dataIntegrity {
        doc /* 
            The system shall ensure data integrity through validation, 
            error checking, and redundancy mechanisms.
        */
        
        subject gauge : permanentDownholeGaugeSystem;
    }
    
    requirement <'PDG-REQ-007'> selfDiagnostics {
        doc /* 
            The system shall perform continuous self-diagnostics and report 
            any faults or degraded performance to surface facilities.
        */
        
        subject gauge : permanentDownholeGaugeSystem;
    }
    
    requirement systemMissionRequirement {
        doc /* 
            The permanent downhole gauge system shall provide continuous, 
            accurate, real-time monitoring of wellbore conditions to enable 
            production optimization, reservoir characterization, and well 
            integrity management throughout the productive life of the well.
        */
        
        assume constraint permanentInstallation {
            doc /* 
                The gauge is permanently installed in the wellbore and cannot 
                be retrieved for maintenance or repair during well operation.
            */
        }
        
        assume constraint harshEnvironment {
            doc /* 
                The gauge operates in extreme downhole conditions with high 
                pressure, high temperature, corrosive fluids, and vibration.
            */
        }
        
        require continuousDataAcquisition;
        require measurementAccuracy;
        require realTimeDataTransmission;
        require environmentalSurvivability;
        require operationalLifetime;
        require dataIntegrity;
        require selfDiagnostics;
    }
}
