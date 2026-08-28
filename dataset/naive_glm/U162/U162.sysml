package BELTRI {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Custom Units =====
    unit def dBm;
    unit def dBi;
    unit def deg;
    unit def Mbps;
    unit def GHz;
    unit def V;
    unit def A;

    // ===== Value Types =====
    value type Frequency :> ISQ::Frequency;
    value type Power :> ISQ::Power;
    value type Length :> ISQ::Length;
    value type Velocity :> ISQ::Velocity;
    value type Time :> ISQ::Time;
    value type SignalStrength :> Real { unit :>> dBm; }
    value type AntennaGain :> Real { unit :>> dBi; }
    value type Angle :> Real { unit :>> deg; }
    value type DataRate :> Real { unit :>> Mbps; }
    value type ClockRate :> Real { unit :>> GHz; }
    value type Voltage :> Real { unit :>> V; }
    value type Current :> Real { unit :>> A; }

    // ===== Item Definitions =====
    item def RFSignal {
        attribute frequency : Frequency;
        attribute strength : SignalStrength;
        attribute timeOfArrival : Time;
        attribute azimuth : Angle;
        attribute elevation : Angle;
    }

    item def ProcessedSignal {
        attribute frequency : Frequency;
        attribute strength : SignalStrength;
        attribute azimuth : Angle;
        attribute elevation : Angle;
        attribute dopplerShift : Frequency;
    }

    item def TargetInfo {
        attribute targetId : String;
        attribute positionX : Length;
        attribute positionY : Length;
        attribute positionZ : Length;
        attribute velocityX : Velocity;
        attribute velocityY : Velocity;
        attribute velocityZ : Velocity;
        attribute signalStrength : SignalStrength;
        attribute classification : String;
    }

    item def IntelligenceData {
        attribute target : TargetInfo;
        attribute timestamp : Time;
        attribute confidence : Real;
    }

    item def Command {
        attribute commandType : String;
        attribute targetId : String;
        attribute priority : Integer;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    // ===== Port Definitions =====
    port def RFOutPort { out signal : RFSignal; }
    port def RFInPort { in signal : RFSignal; }
    port def ProcessedSignalOutPort { out data : ProcessedSignal; }
    port def ProcessedSignalInPort { in data : ProcessedSignal; }
    port def IntelligenceOutPort { out data : IntelligenceData; }
    port def IntelligenceInPort { in data : IntelligenceData; }
    port def CommandOutPort { out cmd : Command; }
    port def CommandInPort { in cmd : Command; }
    port def PowerOutPort { out power : ElectricalPower; }
    port def PowerInPort { in power : ElectricalPower; }

    // ===== Component Part Definitions =====
    part def Antenna {
        port out rfOut : RFOutPort;
        attribute gain : AntennaGain;
        attribute azimuthCoverage : Angle;
        attribute elevationCoverage : Angle;
        attribute operatingFrequency : Frequency;

        action def CaptureSignal {
            in environmentSignal : RFSignal;
            out capturedSignal : RFSignal;
        }

        action capture : CaptureSignal {
            out capturedSignal = rfOut.signal;
        }
    }

    part def ReceiverModule {
        port in rfIn : RFInPort;
        port out processedOut : ProcessedSignalOutPort;
        port in cmdIn : CommandInPort;
        port in powerIn : PowerInPort;
        attribute sensitivity : SignalStrength;
        attribute bandwidth : Frequency;
        attribute noiseFigure : Real;

        action def ReceiveAndPrepare {
            in raw : RFSignal;
            out prepared : ProcessedSignal;
        }

        action receive : ReceiveAndPrepare {
            in raw = rfIn.signal;
            out prepared = processedOut.data;
        }
    }

    part def SignalProcessingUnit {
        port in signalIn : ProcessedSignalInPort;
        port out intelOut : IntelligenceOutPort;
        port in cmdIn : CommandInPort;
        port in powerIn : PowerInPort;
        attribute processingRate : ClockRate;
        attribute detectionThreshold : SignalStrength;

        action def AnalyzeSignal {
            in input : ProcessedSignal;
            out target : TargetInfo;
        }

        action analyze : AnalyzeSignal {
            in input = signalIn.data;
            out target;
        }

        action def ClassifyTarget {
            in target : TargetInfo;
            out classified : TargetInfo;
        }

        action classify : ClassifyTarget {
            in target = analyze.target;
            out classified;
        }

        action packageIntel {
            in target : TargetInfo = classify.classified;
            out data : IntelligenceData = intelOut.data;
        }
    }

    part def TransmitterModule {
        port in intelIn : IntelligenceInPort;
        port out dataOut : IntelligenceOutPort;
        port in cmdIn : CommandInPort;
        port in powerIn : PowerInPort;
        attribute transmitPower : Power;
        attribute dataRate : DataRate;
        attribute modulationScheme : String;

        action def TransmitIntelligence {
            in data : IntelligenceData;
        }

        action transmit : TransmitIntelligence {
            in data = intelIn.data;
            out forwarded : IntelligenceData = dataOut.data;
        }
    }

    part def PowerSupplyUnit {
        port out powerOut : PowerOutPort;
        attribute capacity : Power;
        attribute outputVoltage : Voltage;
        attribute outputCurrent : Current;
        attribute batteryLevel : Real;

        action def SupplyPower {
            out power : ElectricalPower;
        }

        action supply : SupplyPower {
            out power = powerOut.power;
        }
    }

    part def ControlProcessor {
        port in cmdIn : CommandInPort;
        port in statusIn : ProcessedSignalInPort;
        port out controlOut : CommandOutPort;
        port in powerIn : PowerInPort;
        attribute clockSpeed : ClockRate;
        attribute mode : String;

        action def ManageOperation {
            in cmd : Command;
            in status : ProcessedSignal;
            out directive : Command;
        }

        action manage : ManageOperation {
            in cmd = cmdIn.cmd;
            in status = statusIn.data;
            out directive = controlOut.cmd;
        }
    }

    // ===== BELTRI System =====
    part def BELTRI {
        attribute systemName : String = "BELTRI";
        attribute description : String = "Bistatic Electronic Intelligence Tracking and Reconnaissance Instrument";
        attribute maxTargets : Integer = 32;

        part antennas : Antenna[4];
        part receiver : ReceiverModule;
        part processor : SignalProcessingUnit;
        part transmitter : TransmitterModule;
        part powerSupply : PowerSupplyUnit;
        part controller : ControlProcessor;

        port in commandPort : CommandInPort;
        port out intelligencePort : IntelligenceOutPort;

        // Internal event flags for state machine
        attribute scanCommandReceived : Boolean;
        attribute idleCommandReceived : Boolean;
        attribute targetDetected : Boolean;
        attribute targetLost : Boolean;

        connection rfFeed connect antennas.rfOut to receiver.rfIn;
        connection processedFeed connect receiver.processedOut to processor.signalIn;
        connection intelFeed connect processor.intelOut to transmitter.intelIn;
        connection statusLink connect processor.intelOut to controller.statusIn;
        connection commandLink connect commandPort to controller.cmdIn;
        connection controlBus connect controller.controlOut to { receiver.cmdIn, processor.cmdIn, transmitter.cmdIn };
        connection powerBus connect powerSupply.powerOut to { receiver.powerIn, processor.powerIn, transmitter.powerIn, controller.powerIn };
        connection dataLink connect transmitter.dataOut to intelligencePort;

        // ===== State Machine =====
        state machine ModeStateMachine {
            state idle {
                entry { /* Standby: low power, antennas inactive */ }
                do { supply; }
            }

            state scanning {
                entry { /* Activate antenna sweep and receiver */ }
                do { capture; receive; analyze; }
            }

            state tracking {
                entry { /* Focus on detected target */ }
                do { receive; analyze; classify; packageIntel; transmit; }
            }

            transition t_idle_to_scanning
                from idle to scanning
                when { scanCommandReceived }

            transition t_scanning_to_tracking
                from scanning to tracking
                when { targetDetected }

            transition t_tracking_to_scanning
                from tracking to scanning
                when { targetLost }

            transition t_scanning_to_idle
                from scanning to idle
                when { idleCommandReceived }

            transition t_tracking_to_idle
                from tracking to idle
                when { idleCommandReceived }
        }

        // ===== Requirements Satisfaction =====
        satisfy DetectionRequirement by BELTRI;
        satisfy TrackingRequirement by BELTRI;
        satisfy IdentificationRequirement by BELTRI;
        satisfy CommunicationRequirement by transmitter;
        satisfy PowerRequirement by powerSupply;
        satisfy ModeRequirement by BELTRI;
        satisfy AutonomousOperationRequirement by BELTRI;
    }

    // ===== Requirements =====
    requirement def DetectionRequirement {
        subject : BELTRI;
        attribute detectionRange : Length = 500000;
        objective :>> 'The system shall passively detect targets by analyzing emitted or reflected electromagnetic signals.';
    }

    requirement def TrackingRequirement {
        subject : BELTRI;
        attribute minTargets : Integer = 1;
        attribute updateRate : Frequency = 10;
        objective :>> 'The system shall track detected targets and determine position, velocity, signal strength, and classification.';
    }

    requirement def IdentificationRequirement {
        subject : BELTRI;
        attribute classificationAccuracy : Real = 0.95;
        objective :>> 'The system shall identify target type from captured signals.';
    }

    requirement def CommunicationRequirement {
        subject : BELTRI;
        attribute minDataRate : DataRate = 100;
        objective :>> 'The transmitter shall communicate intelligence data at high speed to remote operators or a command center.';
    }

    requirement def PowerRequirement {
        subject : BELTRI;
        attribute endurance : Time = 86400;
        objective :>> 'An internal power supply unit shall power all system components during operation.';
    }

    requirement def ModeRequirement {
        subject : BELTRI;
        objective :>> 'The system shall operate in idle, scanning, and tracking modes, transitioning based on commands or detection events.';
    }

    requirement def AutonomousOperationRequirement {
        subject : BELTRI;
        objective :>> 'The system shall support autonomous operation in the field without continuous operator intervention.';
    }
}
