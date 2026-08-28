package Veinoplus {
    private import ScalarValues::*;
    private import ISQ::*;

    alias Current for ISQ::ElectricCurrentValue;
    alias Frequency for ISQ::FrequencyValue;
    alias Time for ISQ::TimeValue;
    alias Resistance for ScalarValues::Real;
    alias Force for ISQ::ForceValue;
    alias Voltage for ISQ::ElectricPotentialValue;
    alias Energy for ISQ::EnergyValue;
    alias VolumeFlowRate for ISQ::VolumeFlowRateValue;
    alias Velocity for ScalarValues::Real;

    attribute def PowerOnSignal;
    attribute def PowerOffSignal;
    attribute def StartTherapySignal;
    attribute def StopSignal;
    attribute def PauseSignal;
    attribute def ResumeSignal;
    attribute def ProgramChangeSignal;
    attribute def IntensityAdjustSignal;
    attribute def ShutdownSignal;
    attribute def OverLimitAlert;
    attribute def ElectrodeDetached;

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def StimulusPulse {
        attribute waveform : String;
        attribute frequency : Frequency;
        attribute pulseWidth : Time;
        attribute currentAmplitude : Current;
    }

    item def ImpedanceReading {
        attribute skinResistance : Resistance;
        attribute contactQuality : Real;
    }

    item def ProgramSelection {
        attribute programId : Integer;
        attribute mode : String;
    }

    item def IntensitySetting {
        attribute currentAmplitude : Current;
    }

    item def MuscleContraction {
        attribute force : Force;
    }

    item def VenousBloodFlow {
        attribute flowRate : VolumeFlowRate;
        attribute velocity : Velocity;
    }

    port def ElectricalPowerPort { ref item ElectricalPower; }
    port def StimulusPort { ref item StimulusPulse; }
    port def ImpedancePort { ref item ImpedanceReading; }
    port def ProgramPort { ref item ProgramSelection; }
    port def IntensityPort { ref item IntensitySetting; }
    port def ContractionPort { ref item MuscleContraction; }
    port def BloodFlowPort { ref item VenousBloodFlow; }
    port def ControlSignalPort { ref item ShutdownSignal; }

    action def GeneratePulses {
        in program : ProgramSelection;
        in intensity : IntensitySetting;
        out pulseLeft : StimulusPulse;
        out pulseRight : StimulusPulse;
    }

    action def DeliverStimulus {
        in pulse : StimulusPulse;
        out contraction : MuscleContraction;
    }

    action def MonitorSafety {
        in leftImpedance : ImpedanceReading;
        in rightImpedance : ImpedanceReading;
        in intensity : IntensitySetting;
        out shutdown : ShutdownSignal;
    }

    action def CompressVeins {
        in leftContraction : MuscleContraction;
        in rightContraction : MuscleContraction;
        out bloodFlow : VenousBloodFlow;
    }

    action def RunTherapyTimer {
        in sessionDuration : Time;
        out sessionComplete : Boolean;
    }

    action def ProvideTherapy {
        in program : ProgramSelection;
        in intensity : IntensitySetting;
        out bloodFlow : VenousBloodFlow;
    }

    state def ControlStates;
    state def MonitorStates;

    part def BatteryModule {
        attribute chargeLevel : Energy;
        event occurrence depleted;
        event occurrence lowBattery;
        port powerOutControl : ElectricalPowerPort;
        port powerOutPulse : ElectricalPowerPort;
        port powerOutSafety : ElectricalPowerPort;
    }

    part def ControlModule {
        ref item selectedProgram : ProgramSelection;
        ref item intensitySetting : IntensitySetting;
        attribute therapyDuration : Time;
        port powerIn : ElectricalPowerPort;
        port programOut : ProgramPort;
        port intensityOut : IntensityPort;
        port shutdownIn : ControlSignalPort;
        exhibit state controlStates : ControlStates;
    }

    part def PulseGenerator {
        port powerIn : ElectricalPowerPort;
        port programIn : ProgramPort;
        port intensityIn : IntensityPort;
        port pulseOutLeft : StimulusPort;
        port pulseOutRight : StimulusPort;
        perform action generatePulses : GeneratePulses;
    }

    part def SafetyMonitor {
        attribute maxImpedance : Resistance;
        attribute maxIntensity : Current;
        port powerIn : ElectricalPowerPort;
        port impedanceInLeft : ImpedancePort;
        port impedanceInRight : ImpedancePort;
        port intensityIn : IntensityPort;
        port shutdownOut : ControlSignalPort;
        perform action monitorSafety : MonitorSafety;
        exhibit state monitorStates : MonitorStates;
    }

    part def ElectrodePad {
        port pulseIn : StimulusPort;
        port stimulusOut : StimulusPort;
        port impedanceOut : ImpedancePort;
    }

    part def CalfMuscle {
        port stimulusIn : StimulusPort;
        port contractionOut : ContractionPort;
        perform action contract : DeliverStimulus;
    }

    part def VenousVessels {
        port compressionInLeft : ContractionPort;
        port compressionInRight : ContractionPort;
        port bloodFlowOut : BloodFlowPort;
        perform action compress : CompressVeins;
    }

    part def Patient {
        part leftCalfMuscle : CalfMuscle;
        part rightCalfMuscle : CalfMuscle;
        part venousVessels : VenousVessels;
        port bloodFlowOut : BloodFlowPort;
        connect leftCalfMuscle.contractionOut to venousVessels.compressionInLeft;
        connect rightCalfMuscle.contractionOut to venousVessels.compressionInRight;
        connect venousVessels.bloodFlowOut to bloodFlowOut;
    }

    part def VeinoplusDevice {
        part batteryModule : BatteryModule;
        part controlModule : ControlModule;
        part pulseGenerator : PulseGenerator;
        part safetyMonitor : SafetyMonitor;
        port leftPadPort : StimulusPort;
        port rightPadPort : StimulusPort;
        port leftImpedancePort : ImpedancePort;
        port rightImpedancePort : ImpedancePort;
        connect batteryModule.powerOutControl to controlModule.powerIn;
        connect batteryModule.powerOutPulse to pulseGenerator.powerIn;
        connect batteryModule.powerOutSafety to safetyMonitor.powerIn;
        connect controlModule.programOut to pulseGenerator.programIn;
        connect controlModule.intensityOut to pulseGenerator.intensityIn;
        connect controlModule.intensityOut to safetyMonitor.intensityIn;
        connect pulseGenerator.pulseOutLeft to leftPadPort;
        connect pulseGenerator.pulseOutRight to rightPadPort;
        connect leftImpedancePort to safetyMonitor.impedanceInLeft;
        connect rightImpedancePort to safetyMonitor.impedanceInRight;
        connect safetyMonitor.shutdownOut to controlModule.shutdownIn;
    }

    verification def SafeStimulationReq {
        doc /* The device shall ensure stimulation current amplitude never exceeds the safe limit. */
        subject device : PulseGenerator;
    }

    verification def ElectrodeContactReq {
        doc /* The device shall detect electrode detachment and shut down stimulation. */
        subject monitor : SafetyMonitor;
    }

    verification def TherapyControlReq {
        doc /* The device shall allow start, pause, resume, and stop of therapy sessions. */
        subject controller : ControlModule;
    }

    verification def EffectiveCirculationReq {
        doc /* Therapy shall increase venous blood flow rate and velocity above baseline. */
        subject patient : Patient;
    }

    part veinoplusDevice : VeinoplusDevice;
    part leftElectrodePad : ElectrodePad;
    part rightElectrodePad : ElectrodePad;
    part therapyPatient : Patient;

    connect veinoplusDevice.leftPadPort to leftElectrodePad.pulseIn;
    connect veinoplusDevice.rightPadPort to rightElectrodePad.pulseIn;
    connect leftElectrodePad.stimulusOut to therapyPatient.leftCalfMuscle.stimulusIn;
    connect rightElectrodePad.stimulusOut to therapyPatient.rightCalfMuscle.stimulusIn;
    connect leftElectrodePad.impedanceOut to veinoplusDevice.leftImpedancePort;
    connect rightElectrodePad.impedanceOut to veinoplusDevice.rightImpedancePort;

    state controlStates : ControlStates {
        in controller : ControlModule;
        entry; then off;
        state off;
        accept PowerOnSignal then standby;
        state standby;
        accept ProgramChangeSignal then standby;
        accept IntensityAdjustSignal then standby;
        accept StartTherapySignal then stimulating;
        accept PowerOffSignal then off;
        state stimulating {
            do action runTherapyTimer : RunTherapyTimer {
                in sessionDuration = controller.therapyDuration;
            }
        }
        accept PauseSignal then paused;
        accept StopSignal then standby;
        accept ShutdownSignal then off;
        state paused;
        accept ResumeSignal then stimulating;
        accept StopSignal then standby;
        accept ShutdownSignal then off;
    }

    state monitorStates : MonitorStates {
        in controller : ControlModule;
        entry; then normal;
        state normal;
        accept OverLimitAlert
            do send new ShutdownSignal() to controller
            then shutdown;
        accept ElectrodeDetached
            do send new ShutdownSignal() to controller
            then shutdown;
        state shutdown;
    }

    action provideTherapy : ProvideTherapy {
        in program : ProgramSelection;
        in intensity : IntensitySetting;
        out bloodFlow : VenousBloodFlow;

        action generatePulses : GeneratePulses {
            in program = provideTherapy::program;
            in intensity = provideTherapy::intensity;
            out pulseLeft : StimulusPulse;
            out pulseRight : StimulusPulse;
        }

        flow generatePulses.pulseLeft to deliverLeft.pulse;
        flow generatePulses.pulseRight to deliverRight.pulse;

        action deliverLeft : DeliverStimulus {
            in pulse : StimulusPulse;
            out contraction : MuscleContraction;
        }

        action deliverRight : DeliverStimulus {
            in pulse : StimulusPulse;
            out contraction : MuscleContraction;
        }

        flow deliverLeft.contraction to compressVeins.leftContraction;
        flow deliverRight.contraction to compressVeins.rightContraction;

        action compressVeins : CompressVeins {
            in leftContraction : MuscleContraction;
            in rightContraction : MuscleContraction;
            out bloodFlow : VenousBloodFlow;
        }
    }

    verification safeStimulationVer : SafeStimulationReq {
        subject device = veinoplusDevice.pulseGenerator;
    }

    verification electrodeContactVer : ElectrodeContactReq {
        subject monitor = veinoplusDevice.safetyMonitor;
    }

    verification therapyControlVer : TherapyControlReq {
        subject controller = veinoplusDevice.controlModule;
    }

    verification effectiveCirculationVer : EffectiveCirculationReq {
        subject patient = therapyPatient;
    }
}
