package ImpedanceCardiographySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ImpedanceValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def StrokeVolumeValue :> Real;
    attribute def CardiacOutputValue :> Real;
    attribute def HeartRateValue :> Real;
    attribute def TimeIntervalValue :> Real;
    attribute def LengthValue :> Real;
    
    enum def SystemState {
        idle;
        calibrating;
        measuring;
        analyzing;
        displaying;
        alarm;
    }
    
    item def Patient {
        attribute thoracicLength : LengthValue;
        attribute baselineImpedance : ImpedanceValue;
        attribute currentHeartRate : HeartRateValue;
    }
    
    port def CurrentInjectionPort {
        out injectedCurrent : CurrentValue;
        attribute frequency : FrequencyValue;
    }
    
    port def VoltageSensingPort {
        in sensedVoltage : VoltageValue;
    }
    
    port def ImpedanceDataPort {
        out baselineImpedance : ImpedanceValue;
        out impedanceChange : ImpedanceValue;
        out impedanceDerivative : Real;
    }
    
    port def HemodynamicDataPort {
        out heartRate : HeartRateValue;
        out strokeVolume : StrokeVolumeValue;
        out cardiacOutput : CardiacOutputValue;
        out ejectionTime : TimeIntervalValue;
    }
    
    part def HighFrequencyCurrentSource {
        attribute operatingFrequency : FrequencyValue;
        attribute outputCurrent : CurrentValue;
        port currentOutput : CurrentInjectionPort;
        
        assert constraint safeCurrentLevel {
            outputCurrent <= 0.004
        }
        
        action generateConstantCurrent {
            doc /* Generate constant amplitude alternating current at 50-100 kHz */
            in requiredFrequency : FrequencyValue;
            in requiredAmplitude : CurrentValue;
            out generatedCurrent : CurrentValue;
        }
    }
    
    part def ElectrodeSet {
        attribute numberOfElectrodes : Integer;
        port outerElectrodePair : CurrentInjectionPort[2];
        port innerElectrodePair : VoltageSensingPort[2];
        
        assert constraint fourElectrodeConfiguration {
            numberOfElectrodes == 4
        }
        
        action applyCurrentToThorax {
            in current : CurrentValue;
        }
        
        action measureThoracicVoltage {
            out voltage : VoltageValue;
        }
    }
    
    part def SignalAcquisitionUnit {
        port voltageInput : VoltageSensingPort;
        port impedanceOutput : ImpedanceDataPort;
        attribute amplificationGain : Real;
        attribute filterCutoffFrequency : FrequencyValue;
        
        action amplifyVoltageSignal {
            in rawVoltage : VoltageValue;
            out amplifiedVoltage : VoltageValue;
        }
        
        action filterSignal {
            in noisySignal : VoltageValue;
            out cleanSignal : VoltageValue;
        }
        
        action demodulateSignal {
            in modulatedSignal : VoltageValue;
            out baselineZ : ImpedanceValue;
            out deltaZ : ImpedanceValue;
        }
        
        action computeDerivative {
            in impedanceWaveform : ImpedanceValue[*];
            out dZdt : Real;
        }
    }
    
    part def HemodynamicProcessor {
        port impedanceInput : ImpedanceDataPort;
        port hemodynamicOutput : HemodynamicDataPort;
        attribute thoracicLength : LengthValue;
        attribute bloodResistivity : Real;
        
        action detectCardiacEvents {
            in dZdtWaveform : Real[*];
            out peakDZdt : Real;
            out ejectionTime : TimeIntervalValue;
            out heartRate : HeartRateValue;
        }
        
        action calculateStrokeVolume {
            doc /* Calculate stroke volume using Kubicek equation */
            in baselineImpedance : ImpedanceValue;
            in peakDerivative : Real;
            in ejectionTime : TimeIntervalValue;
            in thoracicLength : LengthValue;
            out strokeVolume : StrokeVolumeValue;
        }
        
        action calculateCardiacOutput {
            in strokeVolume : StrokeVolumeValue;
            in heartRate : HeartRateValue;
            out cardiacOutput : CardiacOutputValue;
        }
        
        action assessFluidStatus {
            in baselineImpedance : ImpedanceValue;
            out fluidIndex : Real;
        }
    }
    
    part def DisplayAndAlarmUnit {
        port dataInput : HemodynamicDataPort;
        attribute alarmThresholdLow : CardiacOutputValue;
        attribute alarmThresholdHigh : CardiacOutputValue;
        
        action displayWaveforms {
            in impedanceData : ImpedanceValue[*];
            in derivativeData : Real[*];
        }
        
        action displayHemodynamicParameters {
            in heartRate : HeartRateValue;
            in strokeVolume : StrokeVolumeValue;
            in cardiacOutput : CardiacOutputValue;
        }
        
        action checkAlarmConditions {
            in cardiacOutput : CardiacOutputValue;
            out alarmStatus : Boolean;
        }
        
        action triggerAlarm {
            in alarmCondition : Boolean;
        }
    }
    
    part def SafetyMonitoringUnit {
        attribute maxAllowedCurrent : CurrentValue;
        attribute impedanceRangeMin : ImpedanceValue;
        attribute impedanceRangeMax : ImpedanceValue;
        
        action monitorCurrentSafety {
            in appliedCurrent : CurrentValue;
            out safetyStatus : Boolean;
        }
        
        action detectElectrodeFailure {
            in measuredImpedance : ImpedanceValue;
            out electrodeStatus : Boolean;
        }
        
        action initiateShutdown {
            in safetyViolation : Boolean;
        }
    }
    
    part def ImpedanceCardiograph {
        doc /* 
         * Non-invasive cardiac monitoring system that measures changes in thoracic 
         * electrical impedance to continuously assess hemodynamic parameters including 
         * stroke volume, cardiac output, and fluid status without requiring invasive 
         * catheterization.
         */
        
        attribute systemState : SystemState;
        attribute measurementCycleRate : FrequencyValue;
        
        part currentSource : HighFrequencyCurrentSource {
            attribute :>> operatingFrequency = 70000.0;
            attribute :>> outputCurrent = 0.0035;
        }
        
        part electrodes : ElectrodeSet {
            attribute :>> numberOfElectrodes = 4;
        }
        
        part signalAcquisition : SignalAcquisitionUnit {
            attribute :>> amplificationGain = 1000.0;
            attribute :>> filterCutoffFrequency = 250.0;
        }
        
        part processor : HemodynamicProcessor {
            attribute :>> thoracicLength = 0.28;
            attribute :>> bloodResistivity = 150.0;
        }
        
        part display : DisplayAndAlarmUnit {
            attribute :>> alarmThresholdLow = 3.0;
            attribute :>> alarmThresholdHigh = 8.0;
        }
        
        part safetyMonitor : SafetyMonitoringUnit {
            attribute :>> maxAllowedCurrent = 0.005;
            attribute :>> impedanceRangeMin = 10.0;
            attribute :>> impedanceRangeMax = 100.0;
        }
        
        connection currentInjection connect 
            currentSource.currentOutput to electrodes.outerElectrodePair;
        
        connection voltageMeasurement connect 
            electrodes.innerElectrodePair to signalAcquisition.voltageInput;
        
        connection impedanceProcessing connect 
            signalAcquisition.impedanceOutput to processor.impedanceInput;
        
        connection hemodynamicDisplay connect 
            processor.hemodynamicOutput to display.dataInput;
    }
    
    action def PerformContinuousMonitoring {
        doc /* 
         * Main operational cycle for continuous impedance cardiography monitoring 
         * including signal acquisition, processing, and hemodynamic parameter calculation.
         */
        
        first start;
        
        then action initializeSystem {
            doc /* Power on system and perform self-diagnostics */
        }
        
        then action calibrateBaseline {
            doc /* Establish baseline impedance and calibrate measurement circuits */
            out baselineZ : ImpedanceValue;
        }
        
        then action verifyElectrodePlacement {
            doc /* Check electrode contact impedance and placement quality */
            out placementValid : Boolean;
        }
        
        then merge measurementCycle;
        
        then action injectHighFrequencyCurrent {
            doc /* Apply constant amplitude AC current through outer electrodes */
            out appliedCurrent : CurrentValue;
            out frequency : FrequencyValue;
        }
        
        then action measureVoltageResponse {
            doc /* Sense voltage drop across inner electrode pair */
            in current : CurrentValue;
            out sensedVoltage : VoltageValue;
        }
        
        then action processImpedanceSignal {
            doc /* Amplify, filter, demodulate to extract impedance waveform */
            in voltage : VoltageValue;
            in current : CurrentValue;
            out baselineImpedance : ImpedanceValue;
            out impedanceChange : ImpedanceValue;
            out impedanceDerivative : Real;
        }
        
        then action extractCardiacFeatures {
            doc /* Identify cardiac cycle events from dZ/dt waveform */
            in dZdt : Real;
            out peakDZdt : Real;
            out ejectionTime : TimeIntervalValue;
            out heartRate : HeartRateValue;
        }
        
        then action computeStrokeVolume {
            doc /* Calculate stroke volume using Kubicek or Sramek-Bernstein formula */
            in baselineZ : ImpedanceValue;
            in peakDerivative : Real;
            in ejectionTime : TimeIntervalValue;
            out strokeVolume : StrokeVolumeValue;
        }
        
        then action computeCardiacOutput {
            doc /* Calculate cardiac output as product of stroke volume and heart rate */
            in strokeVolume : StrokeVolumeValue;
            in heartRate : HeartRateValue;
            out cardiacOutput : CardiacOutputValue;
        }
        
        then action updateDisplays {
            doc /* Refresh waveform displays and hemodynamic parameter values */
            in impedanceWaveform : ImpedanceValue[*];
            in hemodynamicData : Real[*];
        }
        
        then action performSafetyChecks {
            doc /* Monitor current levels, electrode status, and parameter validity */
            in currentLevel : CurrentValue;
            in impedanceValue : ImpedanceValue;
            out systemSafe : Boolean;
        }
        
        then decide;
            if performSafetyChecks.systemSafe then measurementCycle;
            if !performSafetyChecks.systemSafe then handleAlarm;
        
        action handleAlarm {
            doc /* Trigger alarm and safely suspend measurement */
        }
        
        then done;
    }
    
    requirement <'REQ-ICG-001'> primaryFunction {
        doc /* 
         * The system shall provide continuous, non-invasive measurement of cardiac 
         * hemodynamic parameters by analyzing thoracic electrical impedance changes 
         * during the cardiac cycle.
         */
        subject icg : ImpedanceCardiograph;
    }
    
    requirement <'REQ-ICG-002'> cardiacOutputAccuracy {
        doc /* 
         * The system shall measure cardiac output with accuracy within ±15% 
         * compared to thermodilution reference method.
         */
        subject icg : ImpedanceCardiograph;
    }
    
    requirement <'REQ-ICG-003'> patientSafety {
        doc /* 
         * The applied current shall not exceed 5 mA RMS at frequencies 
         * between 50-100 kHz to ensure patient electrical safety.
         */
        subject currentSource :>> ImpedanceCardiograph::currentSource;
        assert constraint {
            currentSource.outputCurrent <= 0.005 and
            currentSource.operatingFrequency >= 50000.0 and
            currentSource.operatingFrequency <= 100000.0
        }
    }
    
    requirement <'REQ-ICG-004'> realTimeUpdate {
        doc /* 
         * The system shall update hemodynamic parameters with refresh rate 
         * of at least 1 Hz for real-time clinical monitoring.
         */
        subject icg : ImpedanceCardiograph;
        assert constraint {
            icg.measurementCycleRate >= 1.0
        }
    }
    
    requirement <'REQ-ICG-005'> electrodeConfiguration {
        doc /* 
         * The system shall utilize four-electrode tetrapolar configuration 
         * with separate current injection and voltage sensing electrode pairs.
         */
        subject electrodes :>> ImpedanceCardiograph::electrodes;
        assert constraint {
            electrodes.numberOfElectrodes == 4
        }
    }
    
    requirement <'REQ-ICG-006'> alarmSystem {
        doc /* 
         * The system shall provide visual and audible alarms when cardiac output 
         * falls outside clinically acceptable range (3-8 L/min for adults).
         */
        subject display :>> ImpedanceCardiograph::display;
        assert constraint {
            display.alarmThresholdLow == 3.0 and
            display.alarmThresholdHigh == 8.0
        }
    }
    
    part icgSystem : ImpedanceCardiograph {
        attribute :>> systemState = SystemState::idle;
        attribute :>> measurementCycleRate = 2.0;
        
        perform action monitoring[*] ordered references PerformContinuousMonitoring;
    }
    
    satisfy primaryFunction by icgSystem;
    satisfy cardiacOutputAccuracy by icgSystem;
    satisfy patientSafety by icgSystem.currentSource;
    satisfy realTimeUpdate by icgSystem;
    satisfy electrodeConfiguration by icgSystem.electrodes;
    satisfy alarmSystem by icgSystem.display;
}
