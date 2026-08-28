package DopplerGroundSpeedRadarSystem {
    import ScalarValues::*;

    // ---- Units ----
    unit V;
    unit Hz;
    unit mps;
    unit deg;
    unit W;
    unit s;
    unit A;

    // ---- Value Types ----
    value type Voltage { :>> Real; unit V; }
    value type Current { :>> Real; unit A; }
    value type Frequency { :>> Real; unit Hz; }
    value type Speed { :>> Real; unit mps; }
    value type Angle { :>> Real; unit deg; }
    value type Power { :>> Real; unit W; }
    value type TimeValue { :>> Real; unit s; }

    // ---- Items ----
    item def PowerInput {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    item def RegulatedPower {
        attribute voltage : Voltage;
        attribute maxCurrent : Current;
    }
    item def MicrowaveSignal {
        attribute frequency : Frequency;
        attribute power : Power;
    }
    item def ReflectedSignal {
        attribute frequency : Frequency;
        attribute power : Power;
        attribute snr : Real;
    }
    item def DopplerShift {
        attribute shift : Frequency;
    }
    item def VelocityData {
        attribute groundSpeed : Speed;
        attribute timestamp : TimeValue;
        attribute confidence : Real;
    }
    item def ErrorReport {
        attribute code : Integer;
        attribute message : String;
    }
    item def ControlCommand {
        attribute command : String;
    }
    item def ResetCommand {
        attribute sequenceId : Integer;
    }
    item def StatusMessage {
        attribute state : String;
        attribute healthy : Boolean;
    }

    // ---- Ports ----
    port def VehiclePowerPort {
        in item power : PowerInput;
    }
    port def PowerOutPort {
        out item power : RegulatedPower;
    }
    port def PowerConsumerPort {
        in item power : RegulatedPower;
    }
    port def RFOutPort {
        out item tx : MicrowaveSignal;
    }
    port def RFInPort {
        in item rx : ReflectedSignal;
    }
    port def AntennaPort {
        in item tx : MicrowaveSignal;
        out item rx : ReflectedSignal;
    }
    port def RefOutPort {
        out item ref : MicrowaveSignal;
    }
    port def RefInPort {
        in item ref : MicrowaveSignal;
    }
    port def DataOutPort {
        out item data : VelocityData;
    }
    port def ControlInPort {
        in item command : ControlCommand;
    }
    port def ResetInPort {
        in item reset : ResetCommand;
    }
    port def StatusOutPort {
        out item status : StatusMessage;
    }
    port def ErrorOutPort {
        out item error : ErrorReport;
    }

    // ---- Parts ----
    part def PowerSupplyUnit {
        port powerIn : VehiclePowerPort;
        port powerOut : PowerOutPort;
        attribute primaryVoltage : Voltage = 5 [V];
        attribute secondaryVoltage : Voltage = 12 [V];
        attribute efficiency : Real = 0.90;
        attribute thermalLimit : Temperature = 85 [K]; // placeholder unit not used elsewhere

        action def convertPower {
            in input : PowerInput;
            out output : RegulatedPower;
        }

        perform convertPower;
    }

    part def RFTransmitter {
        port powerIn : PowerConsumerPort;
        port rfOut : RFOutPort;
        port refOut : RefOutPort;
        attribute carrierFrequency : Frequency = 24.125e9 [Hz];
        attribute outputPower : Power = 0.5 [W];
        attribute warmupTime : TimeValue = 0.2 [s];

        action def generateSignal {
            out tx : MicrowaveSignal;
            out ref : MicrowaveSignal;
        }

        perform generateSignal;
    }

    part def AntennaSystem {
        port rfPort : AntennaPort;
        attribute beamAngle : Angle = 45 [deg];
        attribute beamwidth : Angle = 5 [deg];
        attribute gain : Real = 20;

        action def radiateAndCapture {
            in tx : MicrowaveSignal;
            out rx : ReflectedSignal;
        }

        perform radiateAndCapture;
    }

    part def RFReceiver {
        port powerIn : PowerConsumerPort;
        port rfIn : RFInPort;
        port signalOut : RFOutPort;
        attribute gain : Real = 60;
        attribute bandwidth : Frequency = 100e3 [Hz];
        attribute noiseFigure : Real = 2.5;

        item def AmplifiedEcho :> ReflectedSignal;

        action def amplifyAndFilter {
            in rx : ReflectedSignal;
            out echo : AmplifiedEcho;
        }

        perform amplifyAndFilter;
    }

    part def DopplerProcessor {
        port powerIn : PowerConsumerPort;
        port signalIn : RFInPort;
        port refIn : RefInPort;
        port dataOut : DataOutPort;
        port controlIn : ControlInPort;
        port resetIn : ResetInPort;
        port statusOut : StatusOutPort;
        port errorOut : ErrorOutPort;

        attribute beamAngle : Angle = 45 [deg];
        attribute carrierFrequency : Frequency = 24.125e9 [Hz];
        attribute maxUpdateRate : Frequency = 100 [Hz];
        attribute selfTestPassed : Boolean;
        attribute faultDetected : Boolean;
        attribute standbyCommand : Boolean;
        attribute resumeCommand : Boolean;
        attribute resetCommand : Boolean;

        action def computeDopplerShift {
            in ref : MicrowaveSignal;
            in echo : ReflectedSignal;
            out shift : DopplerShift;
        }

        action def computeGroundSpeed {
            in shift : DopplerShift;
            in beamAngle : Angle;
            out data : VelocityData;
        }

        action def runSelfTest {
            out passed : Boolean;
        }

        perform runSelfTest;
        perform computeDopplerShift;
        perform computeGroundSpeed;
    }

    // ---- System ----
    part def DopplerGroundSpeedRadar {
        port vehiclePower : VehiclePowerPort;
        port dataOut : DataOutPort;
        port controlIn : ControlInPort;
        port resetIn : ResetInPort;
        port statusOut : StatusOutPort;
        port errorOut : ErrorOutPort;

        part powerSupply : PowerSupplyUnit;
        part transmitter : RFTransmitter;
        part antenna : AntennaSystem;
        part receiver : RFReceiver;
        part processor : DopplerProcessor;

        // Power distribution
        flow vehiclePower to powerSupply.powerIn;
        flow powerSupply.powerOut to transmitter.powerIn;
        flow powerSupply.powerOut to receiver.powerIn;
        flow powerSupply.powerOut to processor.powerIn;

        // RF transmit path
        flow transmitter.rfOut to antenna.rfPort;
        flow transmitter.refOut to processor.refIn;

        // RF receive path
        flow antenna.rfPort to receiver.rfIn;
        flow receiver.signalOut to processor.signalIn;

        // Data and control
        flow processor.dataOut to dataOut;
        flow controlIn to processor.controlIn;
        flow resetIn to processor.resetIn;
        flow processor.statusOut to statusOut;
        flow processor.errorOut to errorOut;

        // ---- State Machine ----
        state machine RadarStateMachine {
            initial start;
            state initialization {
                entry { processor.runSelfTest(); }
            }
            state operational {
                // Continuous measurement cycle
                do {
                    transmitter.generateSignal();
                    antenna.radiateAndCapture();
                    receiver.amplifyAndFilter();
                    processor.computeDopplerShift();
                    processor.computeGroundSpeed();
                }
            }
            state standby {
                entry { transmitter.outputPower = 0 [W]; }
            }
            state fault {
                entry {
                    transmitter.outputPower = 0 [W];
                    processor.errorOut.send(ErrorReport{code = 1; message = "Fault detected";});
                }
            }

            transition start_to_init {
                from start to initialization;
            }
            transition init_to_op {
                from initialization to operational;
                when processor.selfTestPassed == true;
            }
            transition init_to_fault {
                from initialization to fault;
                when processor.selfTestPassed == false;
            }
            transition op_to_standby {
                from operational to standby;
                when processor.standbyCommand == true;
            }
            transition standby_to_op {
                from standby to operational;
                when processor.resumeCommand == true;
            }
            transition op_to_fault {
                from operational to fault;
                when processor.faultDetected == true;
            }
            transition standby_to_fault {
                from standby to fault;
                when processor.faultDetected == true;
            }
            transition fault_to_init {
                from fault to initialization;
                when processor.resetCommand == true;
            }
        }

        perform RadarStateMachine;
    }

    // ---- Requirements ----
    requirement def MeasureTrueGroundSpeed {
        subject radar : DopplerGroundSpeedRadar;
        objective {
            doc "The radar shall measure the true ground speed of the vehicle independent of wheel slip, wind speed, or GPS availability."
        }
        attribute accuracy : Speed = 0.1 [mps];
        attribute updateRate : Frequency = 100 [Hz];
    }

    requirement def ProvideRegulatedPower {
        subject psu : PowerSupplyUnit;
        objective {
            doc "The PSU shall convert main vehicle power to stable voltages required by radar electronics."
        }
        attribute primaryOutput : Voltage = 5 [V];
        attribute secondaryOutput : Voltage = 12 [V];
    }

    requirement def TransmitMicrowaveSignal {
        subject tx : RFTransmitter;
        objective {
            doc "The transmitter shall generate a high-frequency microwave signal at the carrier frequency."
        }
        attribute carrier : Frequency = 24.125e9 [Hz];
        attribute minPower : Power = 0.5 [W];
    }

    requirement def DirectBeamAtFixedAngle {
        subject ant : AntennaSystem;
        objective {
            doc "The antenna shall focus the microwave signal into a narrow beam directed at a fixed angle toward the ground."
        }
        attribute beamAngle : Angle = 45 [deg];
        attribute maxBeamwidth : Angle = 5 [deg];
    }

    requirement def ReceiveAndConditionEcho {
        subject rx : RFReceiver;
        objective {
            doc "The receiver shall amplify and filter the reflected echo to isolate relevant signal information."
        }
        attribute minGain : Real = 60;
    }

    requirement def ComputeDopplerAndSpeed {
        subject proc : DopplerProcessor;
        objective {
            doc "The processor shall measure the Doppler frequency shift and compute true ground speed using the known antenna beam angle."
        }
    }

    requirement def ImplementOperatingStates {
        subject radar : DopplerGroundSpeedRadar;
        objective {
            doc "The radar shall implement initialization, operational, standby, and fault states with defined transitions."
        }
    }

    requirement def ReportFaults {
        subject radar : DopplerGroundSpeedRadar;
        objective {
            doc "Upon detecting an internal fault, the radar shall shut down its transmitter and report the error, awaiting a reset command."
        }
    }

    // ---- Satisfactions ----
    satisfy ProvideRegulatedPower by powerSupply;
    satisfy TransmitMicrowaveSignal by transmitter;
    satisfy DirectBeamAtFixedAngle by antenna;
    satisfy ReceiveAndConditionEcho by receiver;
    satisfy ComputeDopplerAndSpeed by processor;
    satisfy MeasureTrueGroundSpeed by DopplerGroundSpeedRadar;
    satisfy ImplementOperatingStates by DopplerGroundSpeedRadar::RadarStateMachine;
    satisfy ReportFaults by DopplerGroundSpeedRadar::RadarStateMachine::fault;
}
