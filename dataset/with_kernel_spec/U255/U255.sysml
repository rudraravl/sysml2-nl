package ICG_System {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def StartCommand;
    attribute def CalibrationComplete;
    attribute def MeasurementComplete;
    attribute def AnalysisComplete;
    attribute def UpdateRequest;
    attribute def SafetyViolation;
    attribute def SystemReset;

    item def RawVoltageSignal {
        attribute amplitude : ElectricPotentialValue;
    }

    item def ProcessedImpedanceData {
        attribute baselineImpedance : ResistanceValue;
        attribute deltaImpedance : ResistanceValue;
        attribute dZdtMax : Real;
        attribute LVET : TimeValue;
        attribute heartRate : FrequencyValue;
    }

    item def HemodynamicParameters {
        attribute strokeVolume : VolumeValue;
        attribute heartRate : FrequencyValue;
        attribute cardiacOutput : VolumeValue;
    }

    item def SafetyStatus {
        attribute currentSafe : Boolean;
        attribute contactGood : Boolean;
    }

    item def AlarmSignal {
        attribute alarmText : String;
        attribute severity : Integer;
    }

    item def PatientData {
        attribute thoraxLength : LengthValue;
        attribute bloodResistivity : Real;
    }

    port def CurrentPort {
        out current : ElectricCurrentValue;
    }

    port def VoltagePort {
        out signal : RawVoltageSignal;
    }

    port def ImpedanceDataPort {
        out data : ProcessedImpedanceData;
    }

    port def HemodynamicDataPort {
        out data : HemodynamicParameters;
    }

    port def SafetyStatusPort {
        out status : SafetyStatus;
    }

    port def AlarmPort {
        out alarm : AlarmSignal;
    }

    port def PatientDataPort {
        out data : PatientData;
    }

    interface def CurrentInterface {
        end source : CurrentPort;
        end electrode : CurrentPort;
    }

    interface def VoltageInterface {
        end electrode : VoltagePort;
        end acquisition : VoltagePort;
    }

    interface def ImpedanceDataInterface {
        end provider : ImpedanceDataPort;
        end receiver : ImpedanceDataPort;
    }

    interface def HemodynamicDataInterface {
        end provider : HemodynamicDataPort;
        end receiver : HemodynamicDataPort;
    }

    interface def SafetyStatusInterface {
        end provider : SafetyStatusPort;
        end receiver : SafetyStatusPort;
    }

    interface def AlarmInterface {
        end provider : AlarmPort;
        end receiver : AlarmPort;
    }

    interface def PatientDataInterface {
        end provider : PatientDataPort;
        end receiver : PatientDataPort;
    }

    action def generateCurrent {
        out current : ElectricCurrentValue;
    }

    action def processSignal {
        in rawVoltage : RawVoltageSignal;
        out impedanceData : ProcessedImpedanceData;
    }

    calc def calculateStrokeVolume {
        in rho : Real;
        in L : LengthValue;
        in Z0 : ResistanceValue;
        in dZdtMax : Real;
        in LVET : TimeValue;
        return SV : VolumeValue = rho * (L * L / (Z0 * Z0)) * dZdtMax * LVET;
    }

    calc def calculateCardiacOutput {
        in heartRate : FrequencyValue;
        in strokeVolume : VolumeValue;
        return CO : VolumeValue = heartRate * strokeVolume;
    }

    action def computeHemodynamics {
        in impedanceData : ProcessedImpedanceData;
        in patientData : PatientData;
        out hemodynamicParams : HemodynamicParameters;

        calc calcSV : calculateStrokeVolume {
            in rho = patientData.bloodResistivity;
            in L = patientData.thoraxLength;
            in Z0 = impedanceData.baselineImpedance;
            in dZdtMax = impedanceData.dZdtMax;
            in LVET = impedanceData.LVET;
        }
        calc calcCO : calculateCardiacOutput {
            in heartRate = impedanceData.heartRate;
            in strokeVolume = calcSV.SV;
        }
        bind hemodynamicParams.strokeVolume = calcSV.SV;
        bind hemodynamicParams.heartRate = impedanceData.heartRate;
        bind hemodynamicParams.cardiacOutput = calcCO.CO;
    }

    action def displayAndAlarm {
        in params : HemodynamicParameters;
        in safety : SafetyStatus;
        out alarm : AlarmSignal;
    }

    action def monitorSafety {
        in current : ElectricCurrentValue;
        in contactQuality : ResistanceValue;
        out safetyStatus : SafetyStatus;
        out shutdown : Boolean;
    }

    action def calibrateSystem;
    action def triggerShutdown;

    part def Electrode {
        attribute contactImpedance : ResistanceValue;
        port currentPort : CurrentPort;
        port voltagePort : VoltagePort;
    }

    part def ElectrodeSet {
        part injectElectrode1 : Electrode;
        part injectElectrode2 : Electrode;
        part senseElectrode1 : Electrode;
        part senseElectrode2 : Electrode;
    }

    part def HighFrequencyCurrentSource {
        attribute frequency : FrequencyValue;
        attribute amplitude : ElectricCurrentValue;
        port currentOut : CurrentPort;
        port currentSenseOut : CurrentPort;
        perform action generateCurrent;
    }

    part def SignalAcquisitionUnit {
        port voltageIn : VoltagePort;
        port impedanceDataOut : ImpedanceDataPort;
        perform action processSignal;
    }

    part def HemodynamicProcessor {
        port impedanceDataIn : ImpedanceDataPort;
        port patientDataIn : PatientDataPort;
        port hemodynamicDataOut : HemodynamicDataPort;
        perform action computeHemodynamics;
    }

    part def DisplayAndAlarmUnit {
        port hemodynamicDataIn : HemodynamicDataPort;
        port safetyStatusIn : SafetyStatusPort;
        port alarmOut : AlarmPort;
        attribute safeCOMin : VolumeValue;
        attribute safeCOMax : VolumeValue;
        perform action displayAndAlarm;
    }

    part def SafetyMonitoringUnit {
        port currentMonitor : CurrentPort;
        port voltageMonitor : VoltagePort;
        port safetyStatusOut : SafetyStatusPort;
        port shutdownOut : AlarmPort;
        attribute isSystemSafe : Boolean;
        perform action monitorSafety;
    }

    part def Patient {
        attribute thoraxLength : LengthValue;
    }

    state def ICGOperationStates;

    part def ICGSystem {
        part currentSource : HighFrequencyCurrentSource;
        part electrodes : ElectrodeSet;
        part acquisitionUnit : SignalAcquisitionUnit;
        part processor : HemodynamicProcessor;
        part displayUnit : DisplayAndAlarmUnit;
        part safetyUnit : SafetyMonitoringUnit;

        port patientDataPort : PatientDataPort;
        port alarmPort : AlarmPort;

        interface currentInjection1 : CurrentInterface
            connect currentSource.currentOut to electrodes.injectElectrode1.currentPort;

        interface currentInjection2 : CurrentInterface
            connect currentSource.currentOut to electrodes.injectElectrode2.currentPort;

        interface voltageSense1 : VoltageInterface
            connect electrodes.senseElectrode1.voltagePort to acquisitionUnit.voltageIn;

        interface voltageSense2 : VoltageInterface
            connect electrodes.senseElectrode2.voltagePort to acquisitionUnit.voltageIn;

        interface impedanceDataConn : ImpedanceDataInterface
            connect acquisitionUnit.impedanceDataOut to processor.impedanceDataIn;

        interface hemodynamicDataConn : HemodynamicDataInterface
            connect processor.hemodynamicDataOut to displayUnit.hemodynamicDataIn;

        interface safetyCurrentConn : CurrentInterface
            connect currentSource.currentSenseOut to safetyUnit.currentMonitor;

        interface safetyVoltageConn : VoltageInterface
            connect electrodes.senseElectrode1.voltagePort to safetyUnit.voltageMonitor;

        interface safetyStatusConn : SafetyStatusInterface
            connect safetyUnit.safetyStatusOut to displayUnit.safetyStatusIn;

        interface alarmConn : AlarmInterface
            connect displayUnit.alarmOut to alarmPort;

        interface patientDataConn : PatientDataInterface
            connect patientDataPort to processor.patientDataIn;

        state operationStates : ICGOperationStates {
            entry; then Idle;
            state Idle;
            accept StartCommand then Calibrating;
            state Calibrating;
            accept CalibrationComplete then Measuring;
            state Measuring;
            accept MeasurementComplete then Analyzing;
            state Analyzing;
            accept AnalysisComplete then Displaying;
            state Displaying;
            accept UpdateRequest then Measuring;
            accept SafetyViolation then SafetyFault;
            state SafetyFault;
            accept SystemReset then Calibrating;
        }
    }

    requirement def <'ICG-01'> SafeCurrentLimit {
        doc /* The applied high-frequency alternating current shall not exceed 5 mA RMS to ensure patient safety. */
        subject source : HighFrequencyCurrentSource;
        attribute maxSafeCurrent : ElectricCurrentValue = 0.005 [A];
        require constraint { source.amplitude <= maxSafeCurrent }
    }

    requirement def <'ICG-02'> ElectrodeContactQuality {
        doc /* The electrode-skin contact impedance shall be less than 1 kOhm for reliable signal acquisition. */
        subject electrode : Electrode;
        attribute maxContactImpedance : ResistanceValue = 1000 [ohm];
        require constraint { electrode.contactImpedance <= maxContactImpedance }
    }

    requirement def <'ICG-03'> CardiacOutputSafeRange {
        doc /* The system shall trigger an alarm if cardiac output falls outside the range of 3 to 8 L/min. */
        subject displayUnit : DisplayAndAlarmUnit;
        attribute minCO : VolumeValue = 3 [L];
        attribute maxCO : VolumeValue = 8 [L];
        require constraint {
            displayUnit.safeCOMin == minCO and displayUnit.safeCOMax == maxCO
        }
    }

    requirement def <'ICG-04'> ContinuousRealTimeMonitoring {
        doc /* The system shall provide continuous, real-time monitoring of cardiac output, updating at least once per second. */
        subject icg : ICGSystem;
        attribute maxUpdateInterval : TimeValue = 1 [s];
        require constraint { maxUpdateInterval <= 1 [s] }
    }

    part icgDevice : ICGSystem {
        part :>> currentSource {
            attribute :>> amplitude = 0.002 [A];
            attribute :>> frequency = 100000 [Hz];
        }
        part :>> displayUnit {
            attribute :>> safeCOMin = 3 [L];
            attribute :>> safeCOMax = 8 [L];
        }
    }

    part patient : Patient {
        attribute :>> thoraxLength = 25 [cm];
    }
}
