package SomaneticsOximeterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OxygenSaturationPercentage :> Real {
        doc /* Regional oxygen saturation percentage (rSO2) typically ranging from 0% to 100% */
    }
    
    attribute def WavelengthNanometers :> LengthValue {
        doc /* Wavelength of near-infrared light in nanometers */
    }
    
    attribute def LightIntensityLevel :> Real {
        doc /* Relative intensity of detected light signal */
    }
    
    attribute def ThresholdPercentage :> Real {
        doc /* Alarm threshold for oxygen saturation percentage */
    }
    
    item def NIRLightSignal {
        attribute wavelength : WavelengthNanometers;
        attribute intensity : LightIntensityLevel;
        attribute timestamp : TimeValue;
    }
    
    item def OxygenationMeasurement {
        attribute rSO2Value : OxygenSaturationPercentage;
        attribute measurementTime : TimeValue;
        attribute sensorPosition : String;
        attribute qualityIndicator : Real;
    }
    
    item def AlarmSignal {
        attribute isActive : Boolean;
        attribute severity : String;
        attribute alarmMessage : String;
    }
    
    item def PowerButtonPressed;
    item def StartMonitoringCommand;
    item def StopMonitoringCommand;
    item def CalibrationRequest;
    item def CalibrationFinished;
    
    port def NIREmitterPort {
        out item emittedSignal : NIRLightSignal;
    }
    
    port def NIRReceiverPort {
        in item receivedSignal : NIRLightSignal;
    }
    
    port def DataOutputPort {
        out item measurement : OxygenationMeasurement;
    }
    
    port def AlarmOutputPort {
        out item alarm : AlarmSignal;
    }
    
    port def PowerInputPort {
        in attribute voltage : ISQ::VoltageValue;
        in attribute current : ISQ::ElectricCurrentValue;
    }
    
    part def NIRLightEmitter {
        doc /* Emits near-infrared light at two specific wavelengths for tissue penetration and oxygenation measurement */
        
        port emitterPort : NIREmitterPort;
        port powerPort : PowerInputPort;
        
        attribute wavelength1 : WavelengthNanometers = 730[nm];
        attribute wavelength2 : WavelengthNanometers = 810[nm];
        attribute emissionPower : PowerValue = 0.005[W];
        attribute dutyCycle : Real = 0.5;
    }
    
    part def NIRPhotodetector {
        doc /* Detects reflected near-infrared light from cerebral tissue */
        
        port receiverPort : NIRReceiverPort;
        port powerPort : PowerInputPort;
        
        attribute sensitivity : Real = 0.95;
        attribute responseTime : TimeValue = 0.010[s];
        attribute detectionBandwidth : WavelengthNanometers[2] = (700[nm], 900[nm]);
    }
    
    part def OpticalSensorHead {
        doc /* Combined sensor assembly containing emitter and detector for tissue contact */
        
        part emitter : NIRLightEmitter;
        part detector : NIRPhotodetector;
        
        attribute sensorSpacing : LengthValue = 30[mm];
        attribute adhesiveType : String = "medical_grade";
        attribute sensorID : String;
    }
    
    part def SignalProcessingUnit {
        doc /* Processes raw optical signals to calculate regional oxygen saturation using modified Beer-Lambert law */
        
        in attribute rawSignal730nm : LightIntensityLevel;
        in attribute rawSignal810nm : LightIntensityLevel;
        out attribute calculatedRSO2 : OxygenSaturationPercentage;
        
        attribute extinctionCoeffOxy730 : Real = 0.27;
        attribute extinctionCoeffDeoxy730 : Real = 1.03;
        attribute extinctionCoeffOxy810 : Real = 0.99;
        attribute extinctionCoeffDeoxy810 : Real = 0.69;
        attribute pathLengthFactor : Real = 5.93;
        attribute filterCutoffFreq : FrequencyValue = 0.1[Hz];
    }
    
    part def DisplayModule {
        doc /* Visual display showing real-time and trend data for cerebral oxygenation */
        
        port dataInput : DataOutputPort;
        port powerPort : PowerInputPort;
        
        attribute screenDiagonal : LengthValue = 178[mm];
        attribute resolution : String = "800x480";
        attribute refreshRate : FrequencyValue = 1[Hz];
        attribute trendWindowDuration : TimeValue = 7200[s];
        attribute brightnessLevel : Real = 0.8;
    }
    
    part def AlarmModule {
        doc /* Monitors oxygen saturation levels and generates alarms for critical conditions */
        
        port alarmOutput : AlarmOutputPort;
        port powerPort : PowerInputPort;
        
        in attribute currentRSO2 : OxygenSaturationPercentage;
        
        attribute lowAlarmThreshold : ThresholdPercentage = 50.0;
        attribute criticalAlarmThreshold : ThresholdPercentage = 40.0;
        attribute alarmDelay : TimeValue = 10[s];
        attribute audioVolume : Real = 0.7;
        attribute alarmEnabled : Boolean = true;
    }
    
    part def DataStorageUnit {
        doc /* Stores patient monitoring data for trend analysis and clinical review */
        
        attribute storageCapacity : Real = 1000;
        attribute samplingInterval : TimeValue = 2[s];
        attribute dataRetentionPeriod : TimeValue = 86400[s];
    }
    
    part def PowerSupplyUnit {
        doc /* Provides regulated power to all system components */
        
        attribute inputVoltage : ISQ::VoltageValue = 100[V];
        attribute outputVoltage : ISQ::VoltageValue = 12[V];
        attribute maxCurrent : ISQ::ElectricCurrentValue = 3[A];
        attribute efficiency : Real = 0.85;
        attribute batteryBackupDuration : TimeValue = 3600[s];
    }
    
    action def EmitNIRLight {
        in wavelength : WavelengthNanometers;
        in power : PowerValue;
        out emittedSignal : NIRLightSignal;
    }
    
    action def DetectReflectedLight {
        in receivedSignal : NIRLightSignal;
        out detectedIntensity : LightIntensityLevel;
    }
    
    action def ComputeOxygenSaturation {
        in intensity730 : LightIntensityLevel;
        in intensity810 : LightIntensityLevel;
        in extinctCoeff730Oxy : Real;
        in extinctCoeff730Deoxy : Real;
        in extinctCoeff810Oxy : Real;
        in extinctCoeff810Deoxy : Real;
        out rSO2 : OxygenSaturationPercentage;
        
        doc /* Applies modified Beer-Lambert law to calculate tissue oxygen saturation from dual-wavelength absorption */
    }
    
    action def UpdateDisplayData {
        in measurement : OxygenationMeasurement;
        out displayUpdated : Boolean;
    }
    
    action def EvaluateAlarmCondition {
        in saturation : OxygenSaturationPercentage;
        in lowThreshold : ThresholdPercentage;
        in criticalThreshold : ThresholdPercentage;
        out alarmTriggered : Boolean;
        out alarmLevel : String;
    }
    
    action def StoreDataPoint {
        in measurement : OxygenationMeasurement;
        out dataStored : Boolean;
    }
    
    action def ContinuousCerebralMonitoring {
        doc /* Primary monitoring action that continuously measures and displays cerebral oxygen saturation */
        
        in samplingPeriod : TimeValue = 2[s];
        out measurementHistory : OxygenationMeasurement[*] := ();
        
        private attribute currentRSO2 : OxygenSaturationPercentage;
        private attribute intensity730 : LightIntensityLevel;
        private attribute intensity810 : LightIntensityLevel;
        
        first start;
        then merge monitoringLoop;
        
        then action emit730 : EmitNIRLight {
            in wavelength = 730[nm];
            in power = 0.005[W];
            out emittedSignal;
        }
        
        then action emit810 : EmitNIRLight {
            in wavelength = 810[nm];
            in power = 0.005[W];
            out emittedSignal;
        }
        
        then action detect730 : DetectReflectedLight {
            in receivedSignal;
            out detectedIntensity;
        }
        
        then assign intensity730 := detect730.detectedIntensity;
        
        then action detect810 : DetectReflectedLight {
            in receivedSignal;
            out detectedIntensity;
        }
        
        then assign intensity810 := detect810.detectedIntensity;
        
        then action compute : ComputeOxygenSaturation {
            in intensity730 = intensity730;
            in intensity810 = intensity810;
            in extinctCoeff730Oxy = 0.27;
            in extinctCoeff730Deoxy = 1.03;
            in extinctCoeff810Oxy = 0.99;
            in extinctCoeff810Deoxy = 0.69;
            out rSO2;
        }
        
        then assign currentRSO2 := compute.rSO2;
        
        then action evaluateAlarm : EvaluateAlarmCondition {
            in saturation = currentRSO2;
            in lowThreshold = 50.0;
            in criticalThreshold = 40.0;
            out alarmTriggered;
            out alarmLevel;
        }
        
        then action storeData : StoreDataPoint {
            in measurement;
            out dataStored;
        }
        
        then assign measurementHistory := measurementHistory->including(storeData.measurement);
        
        then action updateDisplay : UpdateDisplayData {
            in measurement;
            out displayUpdated;
        }
        
        then monitoringLoop;
    }
    
    state def SystemOperationalState {
        doc /* State machine governing overall system operation modes */
        
        entry action performSelfTest;
        do action monitoring : ContinuousCerebralMonitoring;
        
        attribute selfTestPassed : Boolean;
        attribute currentRSO2 : OxygenSaturationPercentage;
        attribute lowThreshold : ThresholdPercentage = 50.0;
        
        state powerOff;
        state initialization;
        state standby;
        state activeMonitoring;
        state alarm;
        state calibration;
        state error;
        
        transition powerOn
            first powerOff
            accept PowerButtonPressed
            then initialization;
        
        transition initComplete
            first initialization
            if selfTestPassed
            then standby;
        
        transition initFailed
            first initialization
            if not selfTestPassed
            then error;
        
        transition startMonitoring
            first standby
            accept StartMonitoringCommand
            then activeMonitoring;
        
        transition alarmCondition
            first activeMonitoring
            if currentRSO2 < lowThreshold
            then alarm;
        
        transition alarmCleared
            first alarm
            if currentRSO2 >= lowThreshold
            then activeMonitoring;
        
        transition enterCalibration
            first standby
            accept CalibrationRequest
            then calibration;
        
        transition calibrationComplete
            first calibration
            accept CalibrationFinished
            then standby;
        
        transition stopMonitoring
            first activeMonitoring
            accept StopMonitoringCommand
            then standby;
        
        transition shutdown
            first standby
            accept PowerButtonPressed
            then powerOff;
    }
    
    part def SomaneticsINVOSCerebralOximeter {
        doc /* 
            Somanetics INVOS (In Vivo Optical Spectroscopy) Cerebral Oximeter System.
            
            Primary Function: Non-invasively and continuously monitor regional cerebral 
            oxygen saturation (rSO2) in real-time using near-infrared spectroscopy (NIRS) 
            technology. The system measures the balance between oxygen delivery and consumption 
            in brain tissue by analyzing the differential absorption of two wavelengths of 
            near-infrared light (730nm and 810nm) as they pass through cerebral tissue. 
            
            This enables clinicians to detect cerebral hypoxia and ischemia during surgical 
            procedures, critical care, and other clinical scenarios where brain oxygenation 
            monitoring is essential for patient safety and optimal outcomes.
        */
        
        part leftFrontalSensor : OpticalSensorHead {
            attribute sensorID = "LEFT_FRONTAL_CORTEX";
        }
        
        part rightFrontalSensor : OpticalSensorHead {
            attribute sensorID = "RIGHT_FRONTAL_CORTEX";
        }
        
        part leftProcessor : SignalProcessingUnit;
        part rightProcessor : SignalProcessingUnit;
        
        part display : DisplayModule {
            attribute screenDiagonal = 178[mm];
            attribute trendWindowDuration = 7200[s];
        }
        
        part alarmSystem : AlarmModule {
            attribute lowAlarmThreshold = 50.0;
            attribute criticalAlarmThreshold = 40.0;
        }
        
        part dataStorage : DataStorageUnit {
            attribute storageCapacity = 2000;
            attribute samplingInterval = 2[s];
        }
        
        part powerSupply : PowerSupplyUnit {
            attribute inputVoltage = 100[V];
            attribute outputVoltage = 12[V];
        }
        
        port mainPowerInput : PowerInputPort;
        port leftDataOutput : DataOutputPort;
        port rightDataOutput : DataOutputPort;
        port systemAlarmOutput : AlarmOutputPort;
        
        connect mainPowerInput to powerSupply;
        connect powerSupply to leftFrontalSensor.emitter.powerPort;
        connect powerSupply to leftFrontalSensor.detector.powerPort;
        connect powerSupply to rightFrontalSensor.emitter.powerPort;
        connect powerSupply to rightFrontalSensor.detector.powerPort;
        connect powerSupply to display.powerPort;
        connect powerSupply to alarmSystem.powerPort;
        
        connection leftOpticalPath connect leftFrontalSensor.emitter.emitterPort to leftFrontalSensor.detector.receiverPort;
        connection rightOpticalPath connect rightFrontalSensor.emitter.emitterPort to rightFrontalSensor.detector.receiverPort;
        
        bind leftProcessor.calculatedRSO2 = alarmSystem.currentRSO2;
        
        perform action systemMonitoring : ContinuousCerebralMonitoring {
            in samplingPeriod = 2[s];
            out measurementHistory;
        }
        
        state operationalStateMachine : SystemOperationalState;
    }
    
    requirement def <'REQ-INVOS-001'> ContinuousMonitoringRequirement {
        doc /* 
            The system shall continuously monitor regional cerebral oxygen saturation 
            with a measurement update rate of at least 0.5 Hz (one measurement every 2 seconds).
        */
        
        subject oximeter : SomaneticsINVOSCerebralOximeter;
        
        require constraint {
            oximeter.dataStorage.samplingInterval <= 2[s]
        }
    }
    
    requirement def <'REQ-INVOS-002'> MeasurementAccuracyRequirement {
        doc /* 
            The system shall measure regional oxygen saturation (rSO2) values 
            in the range of 0% to 100% with an accuracy of ±5% absolute.
        */
        
        subject oximeter : SomaneticsINVOSCerebralOximeter;
    }
    
    requirement def <'REQ-INVOS-003'> DualWavelengthRequirement {
        doc /* 
            The system shall utilize near-infrared light at two distinct wavelengths 
            (730nm and 810nm) to differentiate between oxygenated and deoxygenated hemoglobin.
        */
        
        subject emitter : NIRLightEmitter;
        
        require constraint {
            emitter.wavelength1 == 730[nm] and emitter.wavelength2 == 810[nm]
        }
    }
    
    requirement def <'REQ-INVOS-004'> AlarmSystemRequirement {
        doc /* 
            The system shall provide configurable alarm thresholds and generate 
            visual and audible alarms when rSO2 falls below defined limits, 
            with a low threshold at 50% and critical threshold at 40%.
        */
        
        subject alarm : AlarmModule;
        
        require constraint {
            alarm.alarmEnabled == true and
            alarm.lowAlarmThreshold == 50.0 and
            alarm.criticalAlarmThreshold == 40.0 and
            alarm.criticalAlarmThreshold < alarm.lowAlarmThreshold
        }
    }
    
    requirement def <'REQ-INVOS-005'> BilateralMonitoringRequirement {
        doc /* 
            The system shall support simultaneous bilateral monitoring of cerebral 
            oxygenation with independent sensors for left and right frontal cortex regions.
        */
        
        subject oximeter : SomaneticsINVOSCerebralOximeter;
        
        require constraint {
            oximeter.leftFrontalSensor.sensorID != oximeter.rightFrontalSensor.sensorID
        }
    }
    
    requirement def <'REQ-INVOS-006'> TrendDisplayRequirement {
        doc /* 
            The system shall display real-time rSO2 values and historical trend data 
            for at least 2 hours (7200 seconds) of continuous monitoring.
        */
        
        subject display : DisplayModule;
        
        require constraint {
            display.trendWindowDuration >= 7200[s]
        }
    }
    
    requirement def <'REQ-INVOS-007'> PowerBackupRequirement {
        doc /* 
            The system shall include battery backup capability to maintain operation 
            for at least 1 hour (3600 seconds) in the event of AC power loss.
        */
        
        subject power : PowerSupplyUnit;
        
        require constraint {
            power.batteryBackupDuration >= 3600[s]
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for Somanetics INVOS Cerebral Oximeter System */
        
        subject oximeter : SomaneticsINVOSCerebralOximeter;
        
        require continuousMonitoring : ContinuousMonitoringRequirement;
        require measurementAccuracy : MeasurementAccuracyRequirement;
        require dualWavelength : DualWavelengthRequirement;
        require alarmSystem : AlarmSystemRequirement;
        require bilateralMonitoring : BilateralMonitoringRequirement;
        require trendDisplay : TrendDisplayRequirement;
        require powerBackup : PowerBackupRequirement;
    }
    
    part invosSystem : SomaneticsINVOSCerebralOximeter {
        doc /* 
            Complete instantiation of Somanetics INVOS cerebral oximetry system 
            for clinical deployment in operating rooms, intensive care units, 
            and other critical care environments requiring continuous cerebral 
            oxygenation monitoring.
        */
        
        satisfy systemRequirements;
    }
}
