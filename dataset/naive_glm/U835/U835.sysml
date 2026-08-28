package UltrasonicProximitySensingUnit {

    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQElectricity::*;
    import ScalarValues::*;

    // ---- Value Types ----
    attribute def Distance :> Length;
    attribute def TimeOfFlight :> Duration;
    attribute def UltrasonicFrequency :> Frequency;
    attribute def SupplyVoltage :> ElectricPotential;
    attribute def ConfidenceScore :> Real;
    attribute def BatteryCapacity :> Real;

    // ---- Item Definitions ----
    item def TriggerCommand {
        attribute commandId : String;
        attribute priority : Integer = 1;
    }

    item def MeasurementResult {
        attribute distance : Distance;
        attribute confidence : ConfidenceScore;
        attribute timestamp : TimeInstant;
        attribute valid : Boolean;
    }

    item def EchoSignal {
        attribute amplitude : Real;
        attribute detected : Boolean;
        attribute timeOfFlight : TimeOfFlight;
    }

    item def UltrasonicPulse {
        attribute frequency : UltrasonicFrequency = 40.0 [kHz];
        attribute duration : Duration = 0.2 [ms];
        attribute powerLevel : Real = 1.0;
    }

    item def TransmitControl {
        attribute enable : Boolean;
    }

    item def ProcessControl {
        attribute enable : Boolean;
    }

    item def EchoNotification {
        attribute detected : Boolean;
    }

    item def ResultNotification {
        attribute ready : Boolean;
    }

    // ---- Port Definitions ----
    port def TriggerInPort {
        in item trigger : TriggerCommand;
    }

    port def DataOutPort {
        out item result : MeasurementResult;
    }

    port def PowerOutPort {
        out attribute voltage : SupplyVoltage;
    }

    port def PowerInPort {
        in attribute voltage : SupplyVoltage;
    }

    port def PulseOutPort {
        out item pulse : UltrasonicPulse;
    }

    port def EchoInPort {
        in item echo : EchoSignal;
    }

    port def TransmitCmdPort {
        out item cmd : TransmitControl;
    }

    port def TransmitCmdInPort {
        in item cmd : TransmitControl;
    }

    port def EchoNotifyPort {
        out item notify : EchoNotification;
    }

    port def EchoNotifyInPort {
        in item notify : EchoNotification;
    }

    port def ProcessCmdPort {
        out item cmd : ProcessControl;
    }

    port def ProcessCmdInPort {
        in item cmd : ProcessControl;
    }

    port def ResultNotifyPort {
        out item notify : ResultNotification;
    }

    port def ResultNotifyInPort {
        in item notify : ResultNotification;
    }

    port def EchoToProcessorPort {
        out item echo : EchoSignal;
    }

    port def EchoFromTransducerPort {
        in item echo : EchoSignal;
    }

    port def ResultToControlPort {
        out item result : MeasurementResult;
    }

    port def ResultFromProcessorPort {
        in item result : MeasurementResult;
    }

    // ---- Ultrasonic Transducer ----
    part def UltrasonicTransducer {
        port powerIn : PowerInPort;
        port txCmdIn : TransmitCmdInPort;
        port pulseOut : PulseOutPort;
        port echoIn : EchoInPort;
        port echoNotifyOut : EchoNotifyPort;
        port echoToProcessor : EchoToProcessorPort;

        attribute resonantFrequency : UltrasonicFrequency = 40.0 [kHz];
        attribute beamAngle : PlaneAngle = 15.0 [deg];
        attribute maxRange : Distance = 4.0 [m];

        action def TransmitAction {
            in item cmd : TransmitControl;
            out item pulse : UltrasonicPulse;
            perform {
                if cmd.enable then {
                    pulse.frequency := resonantFrequency;
                    pulse.duration := 0.2 [ms];
                    pulse.powerLevel := 1.0;
                }
            }
        }

        action def ListenAction {
            in item echo : EchoSignal;
            out item notify : EchoNotification;
            out item echoOut : EchoSignal;
            perform {
                notify.detected := echo.detected;
                echoOut := echo;
            }
        }

        exhibit state def TransducerBehavior {
            state idle;
            state transmitting;
            state listening;

            transition t1 first idle to transmitting
                when txCmdIn.cmd.enable;
            transition t2 first transmitting to listening
                when pulseOut.pulse.transmitted;
            transition t3 first listening to idle
                when echoIn.echo.detected;
            transition t4 first listening to idle
                when timeout after 50.0 [ms];
        }
    }

    // ---- Signal Processor ----
    part def SignalProcessor {
        port powerIn : PowerInPort;
        port procCmdIn : ProcessCmdInPort;
        port echoFromTransducer : EchoFromTransducerPort;
        port resultToControl : ResultToControlPort;
        port resultNotifyOut : ResultNotifyPort;

        attribute speedOfSound : Real = 343.0 [m/s];
        attribute minConfidenceThreshold : ConfidenceScore = 0.5;

        action def CalculateDistanceAction {
            in item echo : EchoSignal;
            out item result : MeasurementResult;
            perform {
                result.distance := (speedOfSound * echo.timeOfFlight) / 2.0;
                result.confidence := if echo.amplitude > 0.5 then 0.95 else 0.6;
                result.valid := echo.detected and (result.confidence >= minConfidenceThreshold);
                result.timestamp := now();
            }
        }

        exhibit state def ProcessorBehavior {
            state idle;
            state processing;

            transition t1 first idle to processing
                when procCmdIn.cmd.enable;
            transition t2 first processing to idle
                when resultNotifyOut.notify.ready;
        }
    }

    // ---- Control Unit ----
    part def ControlUnit {
        port powerIn : PowerInPort;
        port triggerIn : TriggerInPort;
        port dataOut : DataOutPort;
        port txCmdOut : TransmitCmdPort;
        port echoNotifyIn : EchoNotifyInPort;
        port procCmdOut : ProcessCmdPort;
        port resultFromProcessor : ResultFromProcessorPort;
        port resultNotifyIn : ResultNotifyInPort;

        attribute maxCycleTime : Duration = 100.0 [ms];
        attribute listenTimeout : Duration = 50.0 [ms];

        exhibit state def ControlStateMachine {
            state idle {
                entry attribute powerMode : String = "low";
            }
            state measuring;
            state listening;
            state processing;

            transition t1 first idle to measuring
                when triggerIn.trigger.received;
            transition t2 first measuring to listening
                when txCmdOut.cmd.sent {
                    txCmdOut.cmd.enable := true;
                }
            transition t3 first listening to processing
                when echoNotifyIn.notify.detected;
            transition t4 first listening to idle
                when timeout after listenTimeout;
            transition t5 first processing to idle
                when resultNotifyIn.notify.ready {
                    procCmdOut.cmd.enable := true;
                    dataOut.result := resultFromProcessor.result;
                }
        }
    }

    // ---- Power Supply ----
    part def PowerSupply {
        port transducerPower : PowerOutPort;
        port processorPower : PowerOutPort;
        port controlPower : PowerOutPort;

        attribute outputVoltage : SupplyVoltage = 5.0 [V];
        attribute capacity : BatteryCapacity = 1000.0;
        attribute efficiency : Real = 0.9;

        action def RegulateAction {
            in attribute inputVoltage : SupplyVoltage;
            out attribute outputVoltage : SupplyVoltage;
            perform {
                outputVoltage := 5.0 [V];
            }
        }
    }

    // ---- System ----
    part def UltrasonicProximitySensor {
        port trigger : TriggerInPort;
        port dataOut : DataOutPort;

        part transducer : UltrasonicTransducer;
        part processor : SignalProcessor;
        part controller : ControlUnit;
        part power : PowerSupply;

        connection powerToTransducer connect power.transducerPower to transducer.powerIn;
        connection powerToProcessor connect power.processorPower to processor.powerIn;
        connection powerToController connect power.controlPower to controller.powerIn;

        connection triggerToController connect trigger to controller.triggerIn;

        connection txCmdToTransducer connect controller.txCmdOut to transducer.txCmdIn;
        connection echoNotifyToController connect transducer.echoNotifyOut to controller.echoNotifyIn;
        connection procCmdToProcessor connect controller.procCmdOut to processor.procCmdIn;
        connection resultNotifyToController connect processor.resultNotifyOut to controller.resultNotifyIn;

        connection echoToProcessor connect transducer.echoToProcessor to processor.echoFromTransducer;
        connection resultToController connect processor.resultToControl to controller.resultFromProcessor;
        connection resultToOutput connect controller.dataOut to dataOut;

        attribute systemMaxCycleTime : Duration = 100.0 [ms];
        attribute operatingFrequency : UltrasonicFrequency = 40.0 [kHz];
    }

    // ---- Requirements ----
    requirement def MeasurementCycleRequirement {
        attribute maxCycleTime : Duration = 100.0 [ms];
        subject sensor : UltrasonicProximitySensor;
        require {
            sensor.systemMaxCycleTime <= maxCycleTime;
        }
    }

    requirement def DistanceAccuracyRequirement {
        attribute maxError : Distance = 0.01 [m];
        attribute range : Distance = 4.0 [m];
        subject sensor : UltrasonicProximitySensor;
        require {
            sensor.transducer.maxRange <= range;
        }
    }

    requirement def PowerRequirement {
        attribute supplyVoltage : SupplyVoltage = 5.0 [V];
        subject powerSupply : PowerSupply;
        require {
            powerSupply.outputVoltage == supplyVoltage;
        }
    }

    requirement def IdleStateRequirement {
        subject sensor : UltrasonicProximitySensor;
        require {
            sensor.controller.ControlStateMachine.idle.powerMode == "low";
        }
    }

    requirement def EchoTimeoutRequirement {
        attribute timeout : Duration = 50.0 [ms];
        subject sensor : UltrasonicProximitySensor;
        require {
            sensor.controller.listenTimeout <= timeout;
        }
    }

    requirement def ConfidenceReportingRequirement {
        subject result : MeasurementResult;
        require {
            result.confidence >= 0.0 and result.confidence <= 1.0;
        }
    }

    requirement def UltrasonicFrequencyRequirement {
        attribute freq : UltrasonicFrequency = 40.0 [kHz];
        subject sensor : UltrasonicProximitySensor;
        require {
            sensor.operatingFrequency == freq;
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction satisfy MeasurementCycleRequirement by UltrasonicProximitySensor;
    satisfaction satisfy DistanceAccuracyRequirement by UltrasonicProximitySensor;
    satisfaction satisfy PowerRequirement by PowerSupply;
    satisfaction satisfy IdleStateRequirement by ControlUnit;
    satisfaction satisfy EchoTimeoutRequirement by ControlUnit;
    satisfaction satisfy ConfidenceReportingRequirement by MeasurementResult;
    satisfaction satisfy UltrasonicFrequencyRequirement by UltrasonicProximitySensor;
}
