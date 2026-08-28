package CardiacPacemakerSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def ElectricalSignal {
        attribute amplitude :> ISQ::electricPotential;
        attribute timestamp :> ISQ::time;
        attribute chamber : ChamberType;
    }
    item def PacingPulse {
        attribute amplitude :> ISQ::electricPotential;
        attribute duration :> ISQ::time;
        attribute chamber : ChamberType;
    }
    item def DataPacket {
        attribute payload : String;
        attribute commandType : CommandType;
    }
    item def ControlSettings {
        attribute lowerRateLimit :> ISQ::frequency;
        attribute upperRateLimit :> ISQ::frequency;
        attribute therapyMode : String;
        attribute avDelay :> ISQ::time;
        attribute pulseAmplitude :> ISQ::electricPotential;
        attribute pulseWidth :> ISQ::time;
    }
    item def ElectricalPower {
        attribute voltage :> ISQ::electricPotential;
        attribute current :> ISQ::electricCurrent;
    }

    enum def ChamberType { atrium; ventricle; }
    enum def CommandType { program; query; diagnostic; }

    port def SignalPort {
        inout item signal : ElectricalSignal;
    }
    port def PulsePort {
        inout item pulse : PacingPulse;
    }
    port def DataPort {
        in item data : DataPacket;
        out item command : DataPacket;
    }
    port def LeadPort {
        inout item signal : ElectricalSignal;
        inout item pulse : PacingPulse;
    }
    port def PowerPort {
        out item power : ElectricalPower;
    }

    part def Battery {
        attribute voltage :> ISQ::electricPotential;
        attribute capacity :> ISQ::electricCharge;
        attribute internalResistance :> ISQ::resistance;
        attribute stateOfCharge : Real;
        port powerOut : PowerPort;
    }

    part def SensingAmplifier {
        attribute sensitivity :> ISQ::electricPotential;
        port atrialInput : SignalPort;
        port ventricularInput : SignalPort;
        port senseOutput : ~DataPort;
        port powerInput : ~PowerPort;
    }

    part def TimingCircuit {
        attribute avDelay :> ISQ::time;
        attribute refractoryPeriod :> ISQ::time;
        port controlInterface : ~DataPort;
        port powerInput : ~PowerPort;
    }

    part def PulseGenerator {
        attribute maxAmplitude :> ISQ::electricPotential;
        port atrialOutput : PulsePort;
        port ventricularOutput : PulsePort;
        port controlInput : DataPort;
        port powerInput : ~PowerPort;
    }

    part def Telemetry {
        attribute rfFrequency :> ISQ::frequency;
        port external : ~DataPort;
        port internal : ~DataPort;
        port powerInput : ~PowerPort;
    }

    part def ControlLogic {
        attribute minRate :> ISQ::frequency;
        attribute maxRate :> ISQ::frequency;
        attribute therapyMode : String;
        attribute pacingNeeded : Boolean;
        port sensingPort : DataPort;
        port timingPort : DataPort;
        port pacingPort : ~DataPort;
        port telemetryPort : DataPort;
        port powerInput : ~PowerPort;

        state ControlBehavior {
            entry; then Monitoring;
            state Monitoring {
                entry;
                accept data via sensingPort
                then Evaluating;
            }
            state Evaluating;
            state Pacing {
                entry;
                then Monitoring;
            }
            transition Evaluating to Pacing when pacingNeeded;
            transition Evaluating to Monitoring;
        }
    }

    part def Lead {
        attribute impedance :> ISQ::resistance;
        attribute chamber : ChamberType;
        port heartEnd : LeadPort;
        port deviceEnd : ~LeadPort;
    }

    part def Heart {
        port atriumPort : ~LeadPort;
        port ventriclePort : ~LeadPort;
    }

    part def Pacemaker {
        port atrialLeadPort : LeadPort;
        port ventricularLeadPort : LeadPort;
        port telemetryPort : DataPort;

        part battery : Battery;
        part sensingAmp : SensingAmplifier;
        part timingCircuit : TimingCircuit;
        part pulseGen : PulseGenerator;
        part controlLogic : ControlLogic;
        part telemetry : Telemetry;

        connect battery.powerOut to sensingAmp.powerInput;
        connect battery.powerOut to controlLogic.powerInput;
        connect battery.powerOut to timingCircuit.powerInput;
        connect battery.powerOut to pulseGen.powerInput;
        connect battery.powerOut to telemetry.powerInput;

        connect atrialLeadPort to sensingAmp.atrialInput;
        connect ventricularLeadPort to sensingAmp.ventricularInput;
        connect sensingAmp.senseOutput to controlLogic.sensingPort;
        connect timingCircuit.controlInterface to controlLogic.timingPort;
        connect controlLogic.pacingPort to pulseGen.controlInput;
        connect pulseGen.atrialOutput to atrialLeadPort;
        connect pulseGen.ventricularOutput to ventricularLeadPort;
        connect telemetry.internal to controlLogic.telemetryPort;
        connect telemetry.external to telemetryPort;
    }

    part def PacemakerSystem {
        part pacemaker : Pacemaker;
        part atrialLead : Lead {
            :>> chamber = ChamberType::atrium;
        }
        part ventricularLead : Lead {
            :>> chamber = ChamberType::ventricle;
        }
        part heart : Heart;

        connect pacemaker.atrialLeadPort to atrialLead.deviceEnd;
        connect atrialLead.heartEnd to heart.atriumPort;
        connect pacemaker.ventricularLeadPort to ventricularLead.deviceEnd;
        connect ventricularLead.heartEnd to heart.ventriclePort;
    }

    requirement def PacemakerRequirement {
        subject pacemaker : Pacemaker;
    }

    requirement def BatteryLifeRequirement :> PacemakerRequirement {
        doc /* The battery must sustain operation for a minimum of 10 years under nominal pacing load. */
        attribute minCapacity :> ISQ::electricCharge;
        require constraint { pacemaker.battery.capacity >= minCapacity }
    }

    requirement def PacingRateRequirement :> PacemakerRequirement {
        doc /* The pacemaker shall maintain heart rate within programmed limits. */
        attribute minRate :> ISQ::frequency;
        attribute maxRate :> ISQ::frequency;
        require constraint {
            pacemaker.controlLogic.minRate >= minRate and
            pacemaker.controlLogic.maxRate <= maxRate
        }
    }

    requirement def PacingAmplitudeRequirement :> PacemakerRequirement {
        doc /* Pacing pulses must be adjustable between 0.5V and 8.0V for reliable myocardial capture. */
        attribute minAmplitude :> ISQ::electricPotential;
        attribute maxAmplitude :> ISQ::electricPotential;
        require constraint {
            pacemaker.pulseGen.maxAmplitude >= minAmplitude and
            pacemaker.pulseGen.maxAmplitude <= maxAmplitude
        }
    }

    requirement def DualChamberRequirement :> PacemakerRequirement {
        doc /* The system shall support independent sensing and pacing for both atrium and ventricle. */
        attribute supportsDualChamber : Boolean;
        require constraint { supportsDualChamber == true }
    }

    requirement def TelemetryRequirement :> PacemakerRequirement {
        doc /* Telemetry shall allow wireless programming and diagnostic data retrieval. */
        attribute encryptionEnabled : Boolean;
        require constraint { encryptionEnabled == true }
    }

    analysis def PacemakerAnalysis {
        subject system : PacemakerSystem;
        requirement batteryReq : BatteryLifeRequirement;
        requirement rateReq : PacingRateRequirement;
        requirement amplitudeReq : PacingAmplitudeRequirement;
        requirement dualChamberReq : DualChamberRequirement;
        requirement telemetryReq : TelemetryRequirement;
        objective verifyTherapy {
            doc /* Verify that the pacemaker delivers appropriate therapy under nominal conditions. */
        }
    }
}
