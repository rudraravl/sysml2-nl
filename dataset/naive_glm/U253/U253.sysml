package Hyfrecator {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Power :> Real { unit 'W'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type Temperature :> Real { unit 'K'; }
    value type DutyCycle :> Real { unit '%'; }
    value type Length :> Real { unit 'm'; }
    value type Diameter :> Real { unit 'mm'; }

    // ---- Enumerations ----
    enum OperationalMode {
        desiccation = 0;
        fulguration = 1;
        cutting = 2;
        coagulation = 3;
    }

    // ---- Item definitions ----
    item def ACPower {
        attribute voltage : Voltage;
        attribute frequency : Frequency;
    }
    item def DCPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    item def RFSignal {
        attribute frequency : Frequency;
        attribute power : Power;
        attribute dutyCycle : DutyCycle;
        attribute mode : OperationalMode;
    }
    item def ContactSignal {
        attribute contactDetected : Boolean;
    }
    item def SafetyStatus {
        attribute fault : Boolean;
        attribute shutdownRequested : Boolean;
        attribute reason : String;
    }
    item def Telemetry {
        attribute tissueTemperature : Temperature;
        attribute outputCurrent : Current;
        attribute outputPower : Power;
    }
    item def UserCommand {
        attribute powerOn : Boolean;
        attribute mode : OperationalMode;
        attribute powerLevel : Power;
    }

    // ---- Port definitions ----
    port def ACInPort { in ac : ACPower; }
    port def DCOutPort { out dc : DCPower; }
    port def DCInPort { in dc : DCPower; }
    port def RFOutPort { out rf : RFSignal; }
    port def RFInPort { in rf : RFSignal; }
    port def ContactOutPort { out contact : ContactSignal; }
    port def ContactInPort { in contact : ContactSignal; }
    port def TelemetryOutPort { out telemetry : Telemetry; }
    port def TelemetryInPort { in telemetry : Telemetry; }
    port def SafetyOutPort { out status : SafetyStatus; }
    port def SafetyInPort { in status : SafetyStatus; }
    port def UserCommandInPort { in command : UserCommand; }
    port def OscillatorControlPort {
        in enable : Boolean;
        in mode : OperationalMode;
        in powerLevel : Power;
    }

    // ---- Power Supply ----
    part def PowerSupply {
        port acIn : ACInPort;
        port dcOut : DCOutPort;
        attribute outputVoltage : Voltage = 24 [V];
        attribute maxOutputCurrent : Current = 5 [A];
        attribute efficiency : Real = 0.90;

        action def ConvertACtoDC {
            in ac : ACPower;
            out dc : DCPower;
        }
        perform action convert : ConvertACtoDC {
            in ac = acIn.ac;
            out dc = dcOut.dc;
        }
    }

    // ---- RF Oscillator ----
    part def RFOscillator {
        port dcIn : DCInPort;
        port rfOut : RFOutPort;
        port control : OscillatorControlPort;
        attribute carrierFrequency : Frequency = 3.0e6 [Hz];
        attribute maxOutputPower : Power = 50 [W];
        attribute gain : Real = 1.0;

        action def GenerateRF {
            in dc : DCPower;
            in enable : Boolean;
            in mode : OperationalMode;
            in powerLevel : Power;
            out rf : RFSignal;
        }
        perform action generate : GenerateRF {
            in dc = dcIn.dc;
            in enable = control.enable;
            in mode = control.mode;
            in powerLevel = control.powerLevel;
            out rf = rfOut.rf;
        }
    }

    // ---- Handpiece ----
    part def Handpiece {
        port rfIn : RFInPort;
        port rfOut : RFOutPort;
        port contact : ContactOutPort;
        attribute cableLength : Length = 2.0 [m];
        attribute contactThreshold : Current = 0.001 [A];

        action def DetectContact {
            out contact : ContactSignal;
        }
        perform action detect : DetectContact {
            out contact = contact.contact;
        }
    }

    // ---- Electrode ----
    part def Electrode {
        port rfIn : RFInPort;
        port telemetry : TelemetryOutPort;
        attribute tipDiameter : Diameter = 0.5 [mm];
        attribute thermalResistance : Real = 5.0;

        action def SenseTissue {
            in rf : RFSignal;
            out telemetry : Telemetry;
        }
        perform action sense : SenseTissue {
            in rf = rfIn.rf;
            out telemetry = telemetry.telemetry;
        }
    }

    // ---- Safety Monitor ----
    part def SafetyMonitor {
        port monitor : TelemetryInPort;
        port safety : SafetyOutPort;
        attribute maxTissueTemperature : Temperature = 350 [K];
        attribute maxOutputCurrent : Current = 2.0 [A];
        attribute maxOutputPower : Power = 50 [W];
        attribute fault : Boolean = false;

        state machine def SafetyStateMachine {
            state monitoring;
            state tripped;
            initial -> monitoring;
            transition monitoring -> tripped
                when monitor.telemetry.tissueTemperature > maxTissueTemperature
                    || monitor.telemetry.outputCurrent > maxOutputCurrent
                    || monitor.telemetry.outputPower > maxOutputPower;
            transition tripped -> monitoring
                when monitor.telemetry.tissueTemperature <= maxTissueTemperature
                    && monitor.telemetry.outputCurrent <= maxOutputCurrent
                    && monitor.telemetry.outputPower <= maxOutputPower
                    && safety.status.shutdownRequested == false;
        }
        perform SafetyStateMachine;

        action def EvaluateSafety {
            in telemetry : Telemetry;
            out status : SafetyStatus;
        }
        perform action evaluate : EvaluateSafety {
            in telemetry = monitor.telemetry;
            out status = safety.status;
        }
    }

    // ---- Control Unit ----
    part def ControlUnit {
        port userCommand : UserCommandInPort;
        port contact : ContactInPort;
        port safety : SafetyInPort;
        port oscillatorControl : OscillatorControlPort;
        attribute currentMode : OperationalMode = OperationalMode::desiccation;
        attribute currentPowerLevel : Power = 10 [W];
        attribute enabled : Boolean = false;

        state machine def ControlStateMachine {
            state off;
            state ready;
            state activeTreatment;
            state fault;
            initial -> off;

            transition off -> ready
                when userCommand.command.powerOn == true
                    && safety.status.fault == false;
            transition ready -> off
                when userCommand.command.powerOn == false;
            transition ready -> activeTreatment
                when contact.contact.contactDetected == true
                    && safety.status.fault == false;
            transition activeTreatment -> ready
                when contact.contact.contactDetected == false;
            transition activeTreatment -> fault
                when safety.status.fault == true;
            transition ready -> fault
                when safety.status.fault == true;
            transition fault -> off
                when userCommand.command.powerOn == false;
        }
        perform ControlStateMachine;

        action def IssueControl {
            in command : UserCommand;
            in contactSig : ContactSignal;
            in status : SafetyStatus;
            out enable : Boolean;
            out mode : OperationalMode;
            out powerLevel : Power;
        }
        perform action issue : IssueControl {
            in command = userCommand.command;
            in contactSig = contact.contact;
            in status = safety.status;
            out enable = oscillatorControl.enable;
            out mode = oscillatorControl.mode;
            out powerLevel = oscillatorControl.powerLevel;
        }
    }

    // ---- Top-level Hyfrecator System ----
    part def HyfrecatorSystem {
        port acInput : ACInPort;
        port userInterface : UserCommandInPort;

        part powerSupply : PowerSupply;
        part rfOscillator : RFOscillator;
        part controlUnit : ControlUnit;
        part handpiece : Handpiece;
        part electrode : Electrode;
        part safetyMonitor : SafetyMonitor;

        // Power chain
        connect acInput to powerSupply.acIn;
        connect powerSupply.dcOut to rfOscillator.dcIn;

        // RF delivery chain
        connect rfOscillator.rfOut to handpiece.rfIn;
        connect handpiece.rfOut to electrode.rfIn;

        // Contact detection
        connect handpiece.contact to controlUnit.contact;

        // Telemetry to safety monitor
        connect electrode.telemetry to safetyMonitor.monitor;

        // Safety feedback to control unit
        connect safetyMonitor.safety to controlUnit.safety;

        // User commands to control unit
        connect userInterface to controlUnit.userCommand;

        // Control unit drives oscillator
        connect controlUnit.oscillatorControl to rfOscillator.control;
    }

    // ---- Requirements ----
    requirement def PowerConversionRequirement {
        subject ps : PowerSupply;
        requirement ps.outputVoltage == 24 [V];
        requirement ps.maxOutputCurrent >= 5 [A];
        requirement ps.efficiency >= 0.85;
    }

    requirement def RFGenerationRequirement {
        subject osc : RFOscillator;
        requirement osc.carrierFrequency >= 1.0e6 [Hz];
        requirement osc.carrierFrequency <= 5.0e6 [Hz];
        requirement osc.maxOutputPower <= 50 [W];
    }

    requirement def SafetyMonitorRequirement {
        subject sm : SafetyMonitor;
        requirement sm.maxTissueTemperature <= 350 [K];
        requirement sm.maxOutputCurrent <= 2.0 [A];
        requirement sm.maxOutputPower <= 50 [W];
        requirement sm.safety.status.shutdownRequested == true
            when sm.monitor.telemetry.tissueTemperature > sm.maxTissueTemperature
                || sm.monitor.telemetry.outputCurrent > sm.maxOutputCurrent
                || sm.monitor.telemetry.outputPower > sm.maxOutputPower;
    }

    requirement def ControlStateRequirement {
        subject cu : ControlUnit;
        requirement cu.currentMode in OperationalMode::desiccation..OperationalMode::coagulation;
        requirement cu.currentPowerLevel <= 50 [W];
    }

    requirement def SystemInitializationRequirement {
        subject sys : HyfrecatorSystem;
        requirement sys.controlUnit shall initialize in off state;
        requirement sys.controlUnit shall transition to ready only after powerOn command received;
        requirement sys.controlUnit shall transition to activeTreatment only after contact.contactDetected == true;
        requirement sys.controlUnit shall transition to fault when safety.status.fault == true;
    }

    requirement def EnergyDeliveryRequirement {
        subject sys : HyfrecatorSystem;
        requirement sys.rfOscillator.rfOut.rf.power == sys.controlUnit.oscillatorControl.powerLevel
            when sys.controlUnit is in activeTreatment;
        requirement sys.rfOscillator.rfOut.rf.mode == sys.controlUnit.oscillatorControl.mode
            when sys.controlUnit is in activeTreatment;
    }

    // ---- Requirement satisfactions ----
    satisfaction powerConversionSatisfaction : PowerConversionRequirement {
        subject = powerSupply;
    }
    satisfaction rfGenerationSatisfaction : RFGenerationRequirement {
        subject = rfOscillator;
    }
    satisfaction safetyMonitorSatisfaction : SafetyMonitorRequirement {
        subject = safetyMonitor;
    }
    satisfaction controlStateSatisfaction : ControlStateRequirement {
        subject = controlUnit;
    }
    satisfaction systemInitSatisfaction : SystemInitializationRequirement {
        subject = HyfrecatorSystem;
    }
    satisfaction energyDeliverySatisfaction : EnergyDeliveryRequirement {
        subject = HyfrecatorSystem;
    }
}
