package 'Gas Meter System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MeterSerialNumber;
    attribute def CalibrationStatus;
    attribute def AlarmCode;
    
    attribute def VolumeFlowRateValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def PressureValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def EnergyValue :> Real;
    
    item def NaturalGas {
        attribute flowRate : VolumeFlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }
    
    item def MeasurementData {
        attribute instantaneousFlow : VolumeFlowRateValue;
        attribute cumulativeVolume : VolumeValue;
        attribute correctedVolume : VolumeValue;
        attribute energyValue : EnergyValue;
        attribute timestamp : Real;
    }
    
    item def AlarmNotification {
        attribute code : AlarmCode;
        attribute severity : Integer;
        attribute description : String;
    }
    
    port def GasFlowPort {
        in item gasIn : NaturalGas;
        out item gasOut : NaturalGas;
    }
    
    port def DataPort {
        out item measurementData : MeasurementData;
    }
    
    port def CommunicationPort {
        out item dataTransmission : MeasurementData;
        in item configurationCommand : String;
    }
    
    port def AlarmPort {
        out item alarmSignal : AlarmNotification;
    }
    
    part def FlowMeasurementUnit {
        port gasPort : GasFlowPort;
        out attribute measuredFlowRate : VolumeFlowRateValue;
        
        action measureFlow {
            in gasStream : NaturalGas;
            out flowReading : VolumeFlowRateValue;
        }
    }
    
    part def PressureTransducer {
        in item gasStream : NaturalGas;
        out attribute pressureReading : PressureValue;
        
        action sensePressure {
            in gas : NaturalGas;
            out pressure : PressureValue;
        }
    }
    
    part def TemperatureSensor {
        in item gasStream : NaturalGas;
        out attribute temperatureReading : TemperatureValue;
        
        action senseTemperature {
            in gas : NaturalGas;
            out temperature : TemperatureValue;
        }
    }
    
    part def ComputationModule {
        in attribute rawFlowRate : VolumeFlowRateValue;
        in attribute gasPressure : PressureValue;
        in attribute gasTemperature : TemperatureValue;
        in attribute measurementInterval : Real;
        out attribute correctedVolume : VolumeValue;
        out attribute totalVolume : VolumeValue;
        out attribute energyContent : EnergyValue;
        
        private attribute volumeAccumulator : VolumeValue := 0.0;
        
        action applyPressureTemperatureCorrection {
            in measuredFlow : VolumeFlowRateValue;
            in pressure : PressureValue;
            in temperature : TemperatureValue;
            out correctedFlow : VolumeFlowRateValue;
        }
        
        action integrateVolume {
            in correctedFlow : VolumeFlowRateValue;
            in deltaTime : Real;
            in currentTotal : VolumeValue;
            out volumeIncrement : VolumeValue;
            out newTotal : VolumeValue;
        }
        
        action calculateEnergy {
            in volume : VolumeValue;
            in calorificValue : Real;
            out energy : EnergyValue;
        }
    }
    
    part def DisplayUnit {
        in attribute volumeData : VolumeValue;
        in attribute flowData : VolumeFlowRateValue;
        in attribute energyData : EnergyValue;
        
        action refreshDisplay {
            in volume : VolumeValue;
            in flow : VolumeFlowRateValue;
            in energy : EnergyValue;
        }
    }
    
    part def DataStorageModule {
        in attribute measurementRecord : MeasurementData;
        out attribute storedRecords : MeasurementData[*];
        
        action storeReading {
            in data : MeasurementData;
            out recordId : Integer;
        }
        
        action retrieveHistory {
            in startTime : Real;
            in endTime : Real;
            out historicalData : MeasurementData[*];
        }
    }
    
    part def CommunicationInterface {
        port commPort : CommunicationPort;
        
        action transmitData {
            in data : MeasurementData;
            out transmissionStatus : Boolean;
        }
        
        action receiveConfiguration {
            out configData : String;
        }
    }
    
    part def DiagnosticModule {
        in attribute flowRate : VolumeFlowRateValue;
        in attribute pressure : PressureValue;
        in attribute temperature : TemperatureValue;
        out attribute alarmStatus : AlarmNotification;
        
        action checkFlowAnomalies {
            in flow : VolumeFlowRateValue;
            out isAnomalous : Boolean;
        }
        
        action checkPressureLimits {
            in pressure : PressureValue;
            out isOutOfRange : Boolean;
        }
        
        action generateAlarm {
            in alarmType : AlarmCode;
            out alarm : AlarmNotification;
        }
    }
    
    attribute def SystemReady;
    attribute def FlowDetected;
    attribute def NoFlowDetected;
    attribute def AnomalyDetected;
    attribute def AlarmCleared;
    attribute def MaintenanceRequired;
    attribute def MaintenanceComplete;
    
    state def MeterOperationalStates {
        entry; then initialization;
        
        state initialization {
            entry action performSelfTest;
            entry action loadConfiguration;
        }
        
        transition initialization_to_standby
            first initialization
            accept systemReady : SystemReady
            then standby;
        
        state standby {
            entry action enterLowPowerMode;
        }
        
        transition standby_to_measuring
            first standby
            accept flowDetected : FlowDetected
            then measuring;
        
        state measuring {
            entry action activateSensors;
            do action continuousMeasurement;
            do action updateDisplay;
            do action logData;
        }
        
        transition measuring_to_standby
            first measuring
            accept noFlowDetected : NoFlowDetected
            then standby;
        
        transition measuring_to_alarm
            first measuring
            accept anomalyDetected : AnomalyDetected
            then alarm;
        
        state alarm {
            entry action raiseAlarm;
            entry action notifyRemoteSystem;
        }
        
        transition alarm_to_measuring
            first alarm
            accept alarmCleared : AlarmCleared
            then measuring;
        
        transition alarm_to_maintenance
            first alarm
            accept maintenanceRequired : MaintenanceRequired
            then maintenance;
        
        state maintenance {
            entry action disableMeasurement;
            entry action enableDiagnostics;
        }
        
        transition maintenance_to_initialization
            first maintenance
            accept maintenanceComplete : MaintenanceComplete
            then initialization;
    }
    
    action def PerformGasMetering {
        in attribute samplingPeriod : Real;
        in attribute standardPressure : PressureValue;
        in attribute standardTemperature : TemperatureValue;
        out attribute totalConsumption : VolumeValue;
        out attribute totalEnergy : EnergyValue;
        
        private attribute accumulatedVolume : VolumeValue := 0.0;
        private attribute accumulatedEnergy : EnergyValue := 0.0;
        
        first start;
        then merge measurementCycle;
        
        then action acquireFlowData {
            out flowRate : VolumeFlowRateValue;
        }
        
        then action acquirePressureData {
            out pressure : PressureValue;
        }
        
        then action acquireTemperatureData {
            out temperature : TemperatureValue;
        }
        
        then action correctForConditions {
            in rawFlow : VolumeFlowRateValue = acquireFlowData.flowRate;
            in actualPressure : PressureValue = acquirePressureData.pressure;
            in actualTemperature : TemperatureValue = acquireTemperatureData.temperature;
            in refPressure : PressureValue = standardPressure;
            in refTemperature : TemperatureValue = standardTemperature;
            out correctedFlow : VolumeFlowRateValue;
        }
        
        then action computeVolumeIncrement {
            in flow : VolumeFlowRateValue = correctForConditions.correctedFlow;
            in deltaT : Real = samplingPeriod;
            out volumeDelta : VolumeValue;
        }
        
        then assign accumulatedVolume := accumulatedVolume + computeVolumeIncrement.volumeDelta;
        
        then action computeEnergyIncrement {
            in volumeDelta : VolumeValue = computeVolumeIncrement.volumeDelta;
            in calorificValue : Real;
            out energyDelta : EnergyValue;
        }
        
        then assign accumulatedEnergy := accumulatedEnergy + computeEnergyIncrement.energyDelta;
        
        then action performDiagnostics {
            in flow : VolumeFlowRateValue = acquireFlowData.flowRate;
            in pressure : PressureValue = acquirePressureData.pressure;
            in temperature : TemperatureValue = acquireTemperatureData.temperature;
            out diagnosticStatus : Boolean;
        }
        
        then action recordMeasurement {
            in volume : VolumeValue = accumulatedVolume;
            in energy : EnergyValue = accumulatedEnergy;
            in flow : VolumeFlowRateValue = acquireFlowData.flowRate;
        }
        
        then action waitForNextSample {
            in interval : Real = samplingPeriod;
        }
        
        then measurementCycle;
    }
    
    part def GasMeter {
        doc /*
            A residential or commercial gas meter system that accurately measures
            natural gas consumption. The primary function is to continuously monitor
            gas flow through the meter, apply pressure and temperature compensation
            to calculate standard volume, accumulate total consumption, compute energy
            content, store measurement data, provide local display of consumption
            information, transmit data to remote billing systems, and generate alarms
            for abnormal operating conditions or potential safety issues.
        */
        
        attribute serialNumber : MeterSerialNumber;
        attribute calibrationDate : CalibrationStatus;
        attribute firmwareVersion : String;
        
        port gasInlet : GasFlowPort;
        port gasOutlet : GasFlowPort;
        port dataOutput : DataPort;
        port remoteComm : CommunicationPort;
        port alarmOutput : AlarmPort;
        
        part flowUnit : FlowMeasurementUnit {
            perform action measureFlow;
        }
        
        part pressureSensor : PressureTransducer {
            perform action sensePressure;
        }
        
        part temperatureSensor : TemperatureSensor {
            perform action senseTemperature;
        }
        
        part processor : ComputationModule {
            perform action applyPressureTemperatureCorrection;
            perform action integrateVolume;
            perform action calculateEnergy;
        }
        
        part display : DisplayUnit {
            perform action refreshDisplay;
        }
        
        part dataStorage : DataStorageModule {
            perform action storeReading;
            perform action retrieveHistory;
        }
        
        part commInterface : CommunicationInterface {
            perform action transmitData;
            perform action receiveConfiguration;
        }
        
        part diagnostics : DiagnosticModule {
            perform action checkFlowAnomalies;
            perform action checkPressureLimits;
            perform action generateAlarm;
        }
        
        connection gasInputPath connect gasInlet to flowUnit.gasPort;
        connection gasOutputPath connect flowUnit.gasPort to gasOutlet;
        
        perform action meteringOperation : PerformGasMetering {
            in samplingPeriod : Real;
            in standardPressure : PressureValue;
            in standardTemperature : TemperatureValue;
            out totalConsumption : VolumeValue;
            out totalEnergy : EnergyValue;
        }
        
        exhibit state operationalBehavior : MeterOperationalStates;
    }
    
    part gasMeterSystem : GasMeter;
    
    requirement def MeasurementAccuracyRequirement {
        doc /*
            The gas meter shall measure gas volume with high accuracy across
            the specified operating range.
        */
        
        subject meter : GasMeter;
        
        require constraint accuracyTolerance {
            doc /* Volume measurement accuracy shall be within ±1.5% of actual volume. */
        }
        
        require constraint repeatability {
            doc /* Measurement repeatability shall be within ±0.5%. */
        }
    }
    
    requirement def OperatingConditionsRequirement {
        doc /*
            The gas meter shall operate reliably within specified environmental
            and process conditions.
        */
        
        subject meter : GasMeter;
        
        require constraint pressureRange {
            doc /* Operating pressure range: 0.3 to 10.0 bar. */
        }
        
        require constraint temperatureRange {
            doc /* Operating temperature range: -30°C to +60°C. */
        }
        
        require constraint flowRateRange {
            doc /* Flow rate measurement range: 0.01 to 25 m³/h. */
        }
    }
    
    requirement def DataManagementRequirement {
        doc /*
            The gas meter shall store, display, and transmit consumption data
            according to specified intervals and protocols.
        */
        
        subject meter : GasMeter;
        
        require constraint dataLoggingInterval {
            doc /* Measurement data shall be logged at intervals not exceeding 15 minutes. */
        }
        
        require constraint dataRetention {
            doc /* Historical data shall be retained for minimum 90 days. */
        }
        
        require constraint communicationProtocol {
            doc /* Remote communication shall support standard M-Bus or Modbus protocols. */
        }
    }
    
    requirement def SafetyAndDiagnosticsRequirement {
        doc /*
            The gas meter shall detect and report abnormal conditions that may
            indicate safety hazards or system malfunctions.
        */
        
        subject meter : GasMeter;
        
        require constraint leakDetection {
            doc /* System shall detect and alarm on abnormal flow patterns indicating potential leaks. */
        }
        
        require constraint pressureMonitoring {
            doc /* System shall alarm if pressure exceeds safe operating limits. */
        }
        
        require constraint tamperDetection {
            doc /* System shall detect and log unauthorized access or tampering attempts. */
        }
    }
    
    requirement <'GM-SYS-001'> primaryMeteringFunctionRequirement {
        doc /*
            The gas meter system shall continuously and accurately measure natural
            gas consumption by monitoring flow rate, applying pressure and temperature
            compensation, accumulating total volume consumed, calculating energy content,
            storing measurement history, displaying current consumption locally,
            transmitting data to remote billing and monitoring systems, and generating
            alarms for abnormal conditions or safety concerns.
        */
        
        subject system : GasMeter;
        
        assume constraint gasSupplyPresent {
            doc /* Natural gas supply is available at the meter inlet. */
        }
        
        assume constraint powerSupplyAvailable {
            doc /* Electrical power or battery supply is available for meter operation. */
        }
        
        require measurementAccuracy : MeasurementAccuracyRequirement;
        require operatingConditions : OperatingConditionsRequirement;
        require dataManagement : DataManagementRequirement;
        require safetyAndDiagnostics : SafetyAndDiagnosticsRequirement;
    }
}
