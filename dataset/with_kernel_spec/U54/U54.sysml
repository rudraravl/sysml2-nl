package DeepBrainStimulationTherapySystem {
    private import ScalarValues::*;

    attribute def VoltageValue :> Real;
    attribute def CurrentValue :> Real;
    attribute def FrequencyValue :> Real;
    attribute def PulseWidthValue :> Real;
    attribute def ImpedanceValue :> Real;
    attribute def ChargeValue :> Real;
    attribute def BatteryLevelValue :> Real;

    item def NeuralSignal {
        attribute amplitude : VoltageValue;
        attribute frequency : FrequencyValue;
    }
    item def StimulationPulse {
        attribute amplitude : VoltageValue;
        attribute current : CurrentValue;
        attribute frequency : FrequencyValue;
        attribute pulseWidth : PulseWidthValue;
        attribute chargePerPhase : ChargeValue;
    }
    item def ProgrammingCommand {
        attribute targetAmplitude : VoltageValue;
        attribute targetCurrent : CurrentValue;
        attribute targetFrequency : FrequencyValue;
        attribute targetPulseWidth : PulseWidthValue;
        attribute commandType : String;
    }
    item def ImpedanceReading {
        attribute value : ImpedanceValue;
    }
    item def ChargeReading {
        attribute value : ChargeValue;
    }
    item def BatteryStatus {
        attribute level : BatteryLevelValue;
        attribute lowBattery : Boolean;
    }
    item def TelemetryData {
        attribute batteryStatus : BatteryStatus;
        attribute leadImpedance : ImpedanceReading;
        attribute deliveredCharge : ChargeReading;
        attribute therapyActive : Boolean;
    }

    port def ElectrodeIF {
        in sensedSignal : NeuralSignal;
        out stimPulse : StimulationPulse;
    }
    port def TelemetryIF {
        in command : ProgrammingCommand;
        out data : TelemetryData;
    }

    action def SenseNeuralActivity {
        in signal : NeuralSignal;
    }
    action def AnalyzeNeuralPattern {
        in signal : NeuralSignal;
        out isPathological : Boolean;
    }
    action def CalculateStimulation {
        in isPathological : Boolean;
        out pulse : StimulationPulse;
    }
    action def DeliverStimulation {
        in pulse : StimulationPulse;
    }
    action def MonitorImpedance {
        out reading : ImpedanceReading;
    }
    action def MonitorCharge {
        in pulse : StimulationPulse;
        out reading : ChargeReading;
    }
    action def CheckBattery {
        out status : BatteryStatus;
    }
    action def ProgramIPG {
        in command : ProgrammingCommand;
    }
    action def ReceiveTelemetry {
        in data : TelemetryData;
    }

    state def IPGStateMachine {
        state Off;
        state Standby;
        state ActiveTherapy;
        transition offToStandby first Off then Standby;
        transition standbyToActive first Standby then ActiveTherapy;
        transition activeToStandby first ActiveTherapy then Standby;
        transition standbyToOff first Standby then Off;
    }

    part def Battery {
        attribute level : BatteryLevelValue;
        event occurrence lowBatteryAlert;
    }

    part def ProcessingCircuit {
        port leadPort : ElectrodeIF;
        port telemetryPort : TelemetryIF;
        attribute programmedParameters : ProgrammingCommand;
    }

    part def TelemetryModule {
        port externalPort : TelemetryIF;
        port internalPort : ~TelemetryIF;
    }

    part def ImplantablePulseGenerator {
        port leadPort : ElectrodeIF;
        port wirelessPort : TelemetryIF;
        attribute batteryLevel : BatteryLevelValue;

        part battery : Battery;
        part processingCircuit : ProcessingCircuit;
        part telemetryModule : TelemetryModule;

        bind leadPort = processingCircuit.leadPort;
        bind wirelessPort = telemetryModule.externalPort;
        connect telemetryModule.internalPort to processingCircuit.telemetryPort;

        event occurrence powerOn;
        event occurrence powerOff;
        event occurrence startTherapy;
        event occurrence stopTherapy;
        event occurrence emergencyStop;
        event occurrence impedanceFault;

        state ipgStateMachine : IPGStateMachine;
    }

    part def Electrode {
        attribute impedance : ImpedanceValue;
    }

    part def LeadAssembly {
        port proximalPort : ~ElectrodeIF;
        port distalPort : ElectrodeIF;
        part electrodes[1..4] : Electrode;
        attribute leadImpedance : ImpedanceValue;
    }

    part def ExternalClinicianProgrammer {
        port telemetryPort : ~TelemetryIF;
        attribute programmedParameters : ProgrammingCommand;
        action programIPGAction : ProgramIPG;
        action receiveTelemetryAction : ReceiveTelemetry;
    }

    part def BrainTarget {
        port neuralInterface : ~ElectrodeIF;
        attribute targetName : String;
    }

    part def Patient {
        part brainTarget : BrainTarget;
    }

    requirement def TherapyDelivery {
        /* The system shall deliver controlled electrical pulses to targeted brain areas to modulate abnormal neural activity. */
    }
    requirement def NeuralSensing {
        /* The IPG shall continuously sense neural activity from the implanted electrodes. */
    }
    requirement def ClosedLoopControl {
        /* The system shall operate as a closed-loop therapy, sensing neural activity, analyzing it, and adjusting stimulation parameters in real-time. */
    }
    requirement def ImpedanceMonitoring {
        /* The system shall monitor the electrical impedance of the leads to ensure patient safety. */
    }
    requirement def ChargeMonitoring {
        /* The system shall monitor the delivered charge to ensure safe stimulation limits. */
    }
    requirement def LowBatteryAlert {
        /* The system shall alert the clinician when the IPG battery level is low. */
    }
    requirement def WirelessProgrammability {
        /* The system shall allow clinicians to program and fine-tune stimulation parameters wirelessly via the external programmer. */
    }
    requirement def OperationalStates {
        /* The IPG shall support Off, Standby, and Active Therapy operational states. */
    }

    part dbsTherapySystem {
        part clinicianProgrammer : ExternalClinicianProgrammer;
        part patient : Patient;
        part ipg : ImplantablePulseGenerator;
        part lead : LeadAssembly;

        connect clinicianProgrammer.telemetryPort to ipg.wirelessPort;
        connect ipg.leadPort to lead.proximalPort;
        connect lead.distalPort to patient.brainTarget.neuralInterface;

        flow commandFlow of ProgrammingCommand
            from clinicianProgrammer.telemetryPort.command
            to ipg.wirelessPort.command;
        flow statusFlow of TelemetryData
            from ipg.wirelessPort.data
            to clinicianProgrammer.telemetryPort.data;
        flow neuralSignalFlow of NeuralSignal
            from patient.brainTarget.neuralInterface.sensedSignal
            to lead.distalPort.sensedSignal;
        flow stimPulseFlow of StimulationPulse
            from lead.distalPort.stimPulse
            to patient.brainTarget.neuralInterface.stimPulse;
        flow leadSignalFlow of NeuralSignal
            from lead.proximalPort.sensedSignal
            to ipg.leadPort.sensedSignal;
        flow leadPulseFlow of StimulationPulse
            from ipg.leadPort.stimPulse
            to lead.proximalPort.stimPulse;

        satisfy TherapyDelivery by ipg;
        satisfy NeuralSensing by ipg.processingCircuit;
        satisfy ClosedLoopControl by ipg.ipgStateMachine;
        satisfy ImpedanceMonitoring by ipg.ipgStateMachine;
        satisfy ChargeMonitoring by ipg.ipgStateMachine;
        satisfy LowBatteryAlert by ipg.battery;
        satisfy WirelessProgrammability by clinicianProgrammer;
        satisfy OperationalStates by ipg.ipgStateMachine;
    }
}
