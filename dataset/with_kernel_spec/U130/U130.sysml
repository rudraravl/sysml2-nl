package TMS_System {
    private import ScalarValues::*;
    private import SI::*;

    attribute def MagneticFieldStrengthValue :> Real;
    attribute def PulseFrequencyValue :> Real;
    attribute def StimulationDurationValue :> Real;
    attribute def CoilTemperatureValue :> Real;
    attribute def CoolantFlowRateValue :> Real;
    attribute def DischargeEnergyValue :> Real;
    attribute def ElectricCurrentValue :> Real;
    attribute def PulseIntensityValue :> Real;
    attribute def PositionCoordinateValue :> Real;

    item def Coolant;
    item def MagneticPulse {
        attribute fieldStrength : MagneticFieldStrengthValue;
        attribute frequency : PulseFrequencyValue;
    }
    item def TreatmentProtocol {
        attribute intensity : PulseIntensityValue;
        attribute frequency : PulseFrequencyValue;
        attribute duration : StimulationDurationValue;
        attribute pulseCount : Integer;
    }
    item def CalibrationResult {
        attribute motorThreshold : PulseIntensityValue;
        attribute recommendedIntensity : PulseIntensityValue;
    }
    item def SafetyAlert {
        attribute alertType : String;
        attribute severity : String;
    }

    attribute def StartSignal;
    attribute def StopSignal;
    attribute def EmergencyStopSignal;
    attribute def CalibrationCompleteSignal;
    attribute def PositioningCompleteSignal;
    attribute def StimulationCompleteSignal;
    attribute def OverTempSignal;
    attribute def OverFieldSignal;
    attribute def ResetSignal;

    port def PowerPort {
        attribute current : ElectricCurrentValue;
        attribute energy : DischargeEnergyValue;
    }
    port def CoolantSupplyPort {
        item supply : Coolant;
    }
    port def CoolantReturnPort {
        item returnFlow : Coolant;
    }
    port def ControlCommandPort {
        attribute command : String;
        attribute status : String;
    }
    port def SafetyOutPort {
        item alert : SafetyAlert;
        attribute emergencyStop : EmergencyStopSignal;
    }
    port def PositionCommandPort {
        attribute x : PositionCoordinateValue;
        attribute y : PositionCoordinateValue;
        attribute z : PositionCoordinateValue;
        attribute orientation : PositionCoordinateValue;
    }
    port def MagneticFieldPort {
        attribute fieldStrength : MagneticFieldStrengthValue;
    }
    port def TemperaturePort {
        attribute temperature : CoilTemperatureValue;
    }

    action def PerformCalibration {
        out result : CalibrationResult;
    }
    action def PositionCoil {
        in x : PositionCoordinateValue;
        in y : PositionCoordinateValue;
        in z : PositionCoordinateValue;
        in orientation : PositionCoordinateValue;
    }
    action def GenerateMagneticPulse {
        in intensity : PulseIntensityValue;
        in frequency : PulseFrequencyValue;
        out pulse : MagneticPulse;
    }
    action def CirculateCoolant {
        out flowRate : CoolantFlowRateValue;
    }
    action def MonitorSafetyParameters {
        in coilTemp : CoilTemperatureValue;
        in fieldStrength : MagneticFieldStrengthValue;
        out alert : SafetyAlert;
    }
    action def EmergencyShutdown;

    state def StimulationCoilStates;
    state def CoolingSystemStates;
    state def TMSSystemStates;
    state def SafetyMonitorStates;

    part def StimulationCoil {
        exhibit state 'coil states' : StimulationCoilStates;
        port powerIn : PowerPort;
        port coolantIn : CoolantSupplyPort;
        port coolantReturn : CoolantReturnPort;
        port fieldOut : MagneticFieldPort;
        port tempOut : TemperaturePort;
        attribute coilTemperature : CoilTemperatureValue;
        attribute maxTemperature : CoilTemperatureValue;
        perform action 'generate magnetic pulse' : GenerateMagneticPulse;
    }

    part def PowerSupply {
        port powerOut : PowerPort;
        attribute maxDischargeEnergy : DischargeEnergyValue;
        attribute outputCurrent : ElectricCurrentValue;
    }

    part def CoolingSystem {
        exhibit state 'cooling states' : CoolingSystemStates;
        port coolantOut : CoolantSupplyPort;
        port returnIn : CoolantReturnPort;
        attribute coolantFlowRate : CoolantFlowRateValue;
        perform action 'circulate coolant' : CirculateCoolant;
    }

    part def PositioningArm {
        port positionCmd : ControlCommandPort;
        attribute currentX : PositionCoordinateValue;
        attribute currentY : PositionCoordinateValue;
        attribute currentZ : PositionCoordinateValue;
        attribute currentOrientation : PositionCoordinateValue;
        perform action 'position coil' : PositionCoil;
    }

    part def ControlUnit {
        exhibit state 'system states' : TMSSystemStates;
        port controlPort : ControlCommandPort;
        port safetyIn : SafetyOutPort;
        ref item currentProtocol : TreatmentProtocol;
        ref item calibrationResult : CalibrationResult;
        perform action 'perform calibration' : PerformCalibration;
    }

    part def SafetyMonitor {
        exhibit state 'safety states' : SafetyMonitorStates;
        port safetyOut : SafetyOutPort;
        port tempIn : TemperaturePort;
        port fieldIn : MagneticFieldPort;
        attribute maxCoilTemp : CoilTemperatureValue;
        attribute maxFieldStrength : MagneticFieldStrengthValue;
        perform action 'monitor safety' : MonitorSafetyParameters;
    }

    part def Patient {
        attribute targetRegion : String;
    }

    part def TMSSystem;

    requirement def SafetyRequirement {
        doc /* The TMS system shall continuously monitor coil temperature and magnetic field strength during operation. The system shall automatically shut down if coil temperature exceeds 340 K or magnetic field strength exceeds 3 T. */
    }

    requirement def CalibrationRequirement {
        doc /* The TMS system shall perform a calibration routine before stimulation to determine individual patient motor threshold. The calibration shall determine the appropriate stimulation intensity for the individual patient. */
    }

    requirement def PositioningRequirement {
        doc /* The TMS system shall position the stimulation coil precisely over the targeted brain region. The positioning arm shall achieve placement within 2 mm of target coordinates. */
    }

    requirement def CoolingRequirement {
        doc /* The TMS system shall maintain coil temperature within safe operating limits during sustained stimulation. The cooling system shall circulate coolant at a sufficient flow rate to prevent overheating during continuous operation. */
    }

    requirement def StimulationRequirement {
        doc /* The TMS system shall deliver magnetic pulses according to the programmed treatment protocol. The stimulation coil shall generate magnetic pulses at the specified intensity, frequency, and duration defined by the treatment protocol. */
    }

    requirement def OperationalSequenceRequirement {
        doc /* The TMS system shall follow a defined operational sequence during each treatment session. The system shall transition through idle, calibrating, positioning, and stimulating states in sequence, and shall enter an emergency stop state if any safety limit is exceeded. */
    }

    requirement safetyReq : SafetyRequirement;
    requirement calibrationReq : CalibrationRequirement;
    requirement positioningReq : PositioningRequirement;
    requirement coolingReq : CoolingRequirement;
    requirement stimulationReq : StimulationRequirement;
    requirement operationalSeqReq : OperationalSequenceRequirement;

    action 'perform calibration' : PerformCalibration;
    action 'position coil' : PositionCoil;
    action 'generate magnetic pulse' : GenerateMagneticPulse;
    action 'circulate coolant' : CirculateCoolant;
    action 'monitor safety' : MonitorSafetyParameters;
    action 'emergency shutdown' : EmergencyShutdown;

    part tmsSystem : TMSSystem {
        part stimulationCoil : StimulationCoil {
            :>> maxTemperature = 340;
        }
        part powerSupply : PowerSupply {
            :>> maxDischargeEnergy = 2000;
        }
        part coolingSystem : CoolingSystem;
        part positioningArm : PositioningArm;
        part controlUnit : ControlUnit;
        part safetyMonitor : SafetyMonitor {
            :>> maxCoilTemp = 340;
            :>> maxFieldStrength = 3;
        }
        part patient : Patient;

        connect powerSupply.powerOut to stimulationCoil.powerIn;
        connect coolingSystem.coolantOut to stimulationCoil.coolantIn;
        connect stimulationCoil.coolantReturn to coolingSystem.returnIn;
        connect stimulationCoil.tempOut to safetyMonitor.tempIn;
        connect stimulationCoil.fieldOut to safetyMonitor.fieldIn;
        connect safetyMonitor.safetyOut to controlUnit.safetyIn;
        connect controlUnit.controlPort to positioningArm.positionCmd;

        state 'system states' : TMSSystemStates parallel {
            state 'operational states' {
                entry; then idle;

                state idle;
                accept StartSignal
                    then calibrating;
                accept EmergencyStopSignal
                    then emergencyStop;

                state calibrating {
                    entry 'perform calibration';
                }
                accept CalibrationCompleteSignal
                    then positioning;
                accept EmergencyStopSignal
                    then emergencyStop;

                state positioning {
                    entry 'position coil';
                }
                accept PositioningCompleteSignal
                    then stimulating;
                accept EmergencyStopSignal
                    then emergencyStop;

                state stimulating parallel {
                    state 'pulse generation' {
                        do 'generate magnetic pulse';
                    }
                    state 'thermal management' {
                        do 'circulate coolant';
                    }
                    state 'safety oversight' {
                        do 'monitor safety';
                    }
                }
                accept StimulationCompleteSignal
                    then complete;
                accept EmergencyStopSignal
                    then emergencyStop;

                state complete;
                accept ResetSignal
                    then idle;

                state emergencyStop {
                    entry 'emergency shutdown';
                }
                accept ResetSignal
                    then idle;
            }

            state 'safety states' {
                entry; then monitoring;

                state monitoring;
                accept when stimulationCoil.coilTemperature > safetyMonitor.maxCoilTemp
                    do send new OverTempSignal() to controlUnit
                    then alert;
                accept when stimulationCoil.fieldOut.fieldStrength > safetyMonitor.maxFieldStrength
                    do send new OverFieldSignal() to controlUnit
                    then alert;

                state alert {
                    entry 'emergency shutdown';
                }
                accept ResetSignal
                    then monitoring;
            }
        }
    }

    satisfy safetyReq by tmsSystem.safetyMonitor;
    satisfy calibrationReq by tmsSystem.controlUnit;
    satisfy positioningReq by tmsSystem.positioningArm;
    satisfy coolingReq by tmsSystem.coolingSystem;
    satisfy stimulationReq by tmsSystem.stimulationCoil;
    satisfy operationalSeqReq by tmsSystem;
}
