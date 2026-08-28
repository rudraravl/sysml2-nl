package IPC_System {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def PressureValue :> Real {
        unit mmHg;
    }

    value def VolumeValue :> Real {
        unit mL;
    }

    value def FlowRateValue :> Real {
        unit "L/min";
    }

    value def DurationValue :> Real {
        unit s;
    }

    value def PressureThreshold :> Real {
        unit mmHg;
    }

    // ===== Item Types =====

    item def PressurizedAir {
        attribute pressure : PressureValue;
        attribute volume : VolumeValue;
    }

    item def ControlCommand {
        attribute targetChamber : String;
        attribute action : String; // "inflate", "hold", "deflate"
        attribute targetPressure : PressureValue;
    }

    item def PressureReading {
        attribute measuredPressure : PressureValue;
        attribute timestamp : DurationValue;
    }

    item def SafetyAlert {
        attribute alertType : String; // "overpressure", "normal"
        attribute pressureAtAlert : PressureValue;
    }

    // ===== Enumeration =====

    enum def ChamberPosition {
        distal = 0;
        middle = 1;
        proximal = 2;
    }

    enum def TherapyState {
        idle;
        inflating;
        holding;
        deflating;
        resting;
        emergencyShutdown;
    }

    enum def ValveState {
        closed;
        open_inflate;
        open_deflate;
    }

    // ===== Requirements =====

    requirement def TherapyPressureRequirement {
        doc /* The system shall achieve and maintain a prescribed therapeutic pressure within each chamber. */
        attribute prescribedPressure : PressureValue = 40 [mmHg];
        attribute tolerance : PressureValue = 5 [mmHg];
        subject compressionSleeve : CompressionSleeve;
        require { compressionSleeve.actualPressure >= (prescribedPressure - tolerance) and
                  compressionSleeve.actualPressure <= (prescribedPressure + tolerance) }
    }

    requirement def SequentialInflationRequirement {
        doc /* The system shall inflate chambers sequentially from distal to proximal. */
        subject controller : Controller;
        require { controller.inflationSequence == ChamberPosition::distal then
                  ChamberPosition::middle then ChamberPosition::proximal }
    }

    requirement def SafetyShutdownRequirement {
        doc /* The system shall trigger an emergency shutdown if pressure exceeds the maximum safe limit. */
        attribute maxSafePressure : PressureValue = 80 [mmHg];
        subject safetyMonitor : SafetyMonitor;
        require { if safetyMonitor.observedPressure > maxSafePressure then
                  safetyMonitor.shutdownTriggered == true }
    }

    requirement def CycleDurationRequirement {
        doc /* Each therapy cycle shall consist of inflation, hold, deflation, and rest within specified durations. */
        attribute inflationDuration : DurationValue = 10 [s];
        attribute holdDuration : DurationValue = 30 [s];
        attribute deflationDuration : DurationValue = 8 [s];
        attribute restDuration : DurationValue = 12 [s];
        subject controller : Controller;
        require { controller.cycleComplete == true }
    }

    // ===== Port Definitions =====

    port def AirPort {
        attribute pressure : PressureValue;
        inout air : PressurizedAir;
    }

    port def CommandPort {
        out command : ControlCommand;
    }

    port def FeedbackPort {
        in reading : PressureReading;
    }

    port def SafetyCommandPort {
        out alert : SafetyAlert;
    }

    // ===== Chamber =====

    part def CompressionChamber {
        attribute position : ChamberPosition;
        attribute targetPressure : PressureValue = 40 [mmHg];
        attribute currentPressure : PressureValue = 0 [mmHg];
        attribute maxVolume : VolumeValue = 500 [mL];
        attribute currentVolume : VolumeValue = 0 [mL];

        port airIn : AirPort;
        port airOut : AirPort;

        state def ChamberBehavior {
            entry; then deflated;

            state deflated {
                entry { currentPressure = 0 [mmHg]; currentVolume = 0 [mL]; }
            }

            state inflating {
                entry { currentPressure = targetPressure; }
            }

            state holding {
                entry { currentPressure = targetPressure; }
            }

            state deflating {
                entry { currentPressure = 0 [mmHg]; currentVolume = 0 [mL]; }
            }

            transition deflated_to_inflating
                first deflated then inflating
                when airIn.air.pressure > 0 [mmHg];

            transition inflating_to_holding
                first inflating then holding
                when currentPressure >= targetPressure;

            transition holding_to_deflating
                first holding then deflating
                when airOut.air.pressure == 0 [mmHg];
        }

        exhibit state ChamberBehavior;
    }

    // ===== Compression Sleeve =====

    part def CompressionSleeve {
        attribute actualPressure : PressureValue = 0 [mmHg];
        attribute prescribedPressure : PressureValue = 40 [mmHg];

        part distalChamber : CompressionChamber {
            redefines position = ChamberPosition::distal;
            redefines targetPressure = 40 [mmHg];
        }

        part middleChamber : CompressionChamber {
            redefines position = ChamberPosition::middle;
            redefines targetPressure = 40 [mmHg];
        }

        part proximalChamber : CompressionChamber {
            redefines position = ChamberPosition::proximal;
            redefines targetPressure = 40 [mmHg];
        }

        port sleeveAirIn : AirPort;
        port sleevePressureFeedback : FeedbackPort;

        connection def AirDistribution {
            end source : AirPort;
            end target : AirPort;
        }

        connection airToDistal : AirDistribution connect sleeveAirIn to distalChamber.airIn;
        connection airToMiddle : AirDistribution connect sleeveAirIn to middleChamber.airIn;
        connection airToProximal : AirDistribution connect sleeveAirIn to proximalChamber.airIn;

        connection distalExhaust : AirDistribution connect distalChamber.airOut to sleeveAirIn;
        connection middleExhaust : AirDistribution connect middleChamber.airOut to sleeveAirIn;
        connection proximalExhaust : AirDistribution connect proximalChamber.airOut to sleeveAirIn;

        compute pressureAggregate {
            actualPressure = (distalChamber.currentPressure + middleChamber.currentPressure + proximalChamber.currentPressure) / 3;
        }
    }

    // ===== Air Compressor =====

    part def AirCompressor {
        attribute outputPressure : PressureValue = 50 [mmHg];
        attribute maxFlowRate : FlowRateValue = 20 ["L/min"];
        attribute isRunning : Boolean = false;

        port compressedAirOut : AirPort;
        port compressorControl : CommandPort;

        action def GenerateCompressedAir {
            in targetPressure : PressureValue;
            out generatedAir : PressurizedAir;
        }

        perform action generateAir : GenerateCompressedAir {
            when compressorControl.command.action == "inflate";
        }

        exhibit {
            when compressorControl.command.action == "inflate" {
                isRunning = true;
                compressedAirOut.air.pressure = outputPressure;
            }
            when compressorControl.command.action == "deflate" or compressorControl.command.action == "hold" {
                isRunning = false;
            }
        }
    }

    // ===== Valve Manifold =====

    part def ValveManifold {
        attribute valveDistalState : ValveState = ValveState::closed;
        attribute valveMiddleState : ValveState = ValveState::closed;
        attribute valveProximalState : ValveState = ValveState::closed;

        port manifoldAirIn : AirPort;
        port manifoldAirOutDistal : AirPort;
        port manifoldAirOutMiddle : AirPort;
        port manifoldAirOutProximal : AirPort;
        port manifoldCommand : CommandPort;
        port manifoldExhaust : AirPort;

        action def RouteAir {
            in command : ControlCommand;
            in incomingAir : PressurizedAir;
            out routedAir : PressurizedAir;
        }

        perform action routeAir : RouteAir;

        exhibit {
            when manifoldCommand.command.targetChamber == "distal" and manifoldCommand.command.action == "inflate" {
                valveDistalState = ValveState::open_inflate;
                valveMiddleState = ValveState::closed;
                valveProximalState = ValveState::closed;
                manifoldAirOutDistal.air = manifoldAirIn.air;
            }
            when manifoldCommand.command.targetChamber == "middle" and manifoldCommand.command.action == "inflate" {
                valveDistalState = ValveState::closed;
                valveMiddleState = ValveState::open_inflate;
                valveProximalState = ValveState::closed;
                manifoldAirOutMiddle.air = manifoldAirIn.air;
            }
            when manifoldCommand.command.targetChamber == "proximal" and manifoldCommand.command.action == "inflate" {
                valveDistalState = ValveState::closed;
                valveMiddleState = ValveState::closed;
                valveProximalState = ValveState::open_inflate;
                manifoldAirOutProximal.air = manifoldAirIn.air;
            }
            when manifoldCommand.command.action == "deflate" {
                valveDistalState = ValveState::open_deflate;
                valveMiddleState = ValveState::open_deflate;
                valveProximalState = ValveState::open_deflate;
            }
            when manifoldCommand.command.action == "hold" {
                valveDistalState = ValveState::closed;
                valveMiddleState = ValveState::closed;
                valveProximalState = ValveState::closed;
            }
        }
    }

    // ===== Pressure Sensor =====

    part def PressureSensor {
        attribute samplingRate : DurationValue = 0.1 [s];
        attribute measuredPressure : PressureValue = 0 [mmHg];
        attribute isCalibrated : Boolean = true;

        port sensorInput : AirPort;
        port sensorOutput : FeedbackPort;

        action def MeasurePressure {
            in airSample : PressurizedAir;
            out reading : PressureReading;
        }

        perform action measure : MeasurePressure {
            reading.measuredPressure = airSample.pressure;
            reading.timestamp = 0 [s];
        }

        exhibit {
            measuredPressure = sensorInput.air.pressure;
            sensorOutput.reading.measuredPressure = measuredPressure;
        }
    }

    // ===== Safety Monitor =====

    part def SafetyMonitor {
        attribute maxSafePressure : PressureValue = 80 [mmHg];
        attribute warningPressure : PressureValue = 70 [mmHg];
        attribute observedPressure : PressureValue = 0 [mmHg];
        attribute shutdownTriggered : Boolean = false;
        attribute alertActive : Boolean = false;

        port safetyFeedback : FeedbackPort;
        port safetyAlertPort : SafetyCommandPort;

        state def SafetyMonitorBehavior {
            entry; then monitoring;

            state monitoring {
                entry { observedPressure = safetyFeedback.reading.measuredPressure; }
                do { observedPressure = safetyFeedback.reading.measuredPressure; }
            }

            state warning {
                entry { alertActive = true; safetyAlertPort.alert.alertType = "warning"; }
            }

            state emergencyShutdown {
                entry { shutdownTriggered = true; safetyAlertPort.alert.alertType = "overpressure"; }
            }

            transition monitoring_to_warning
                first monitoring then warning
                when observedPressure > warningPressure and observedPressure <= maxSafePressure;

            transition warning_to_monitoring
                first warning then monitoring
                when observedPressure <= warningPressure;

            transition monitoring_to_emergency
                first monitoring then emergencyShutdown
                when observedPressure > maxSafePressure;

            transition warning_to_emergency
                first warning then emergencyShutdown
                when observedPressure > maxSafePressure;
        }

        exhibit state SafetyMonitorBehavior;
    }

    // ===== Controller =====

    part def Controller {
        attribute prescribedPressure : PressureValue = 40 [mmHg];
        attribute maxSafePressure : PressureValue = 80 [mmHg];
        attribute inflationDuration : DurationValue = 10 [s];
        attribute holdDuration : DurationValue = 30 [s];
        attribute deflationDuration : DurationValue = 8 [s];
        attribute restDuration : DurationValue = 12 [s];
        attribute currentTherapyState : TherapyState = TherapyState::idle;
        attribute cycleComplete : Boolean = false;
        attribute inflationSequence : ChamberPosition = ChamberPosition::distal;
        attribute sessionActive : Boolean = false;
        attribute currentChamber : ChamberPosition = ChamberPosition::distal;
        attribute elapsedInflationTime : DurationValue = 0 [s];
        attribute elapsedHoldTime : DurationValue = 0 [s];
        attribute elapsedDeflationTime : DurationValue = 0 [s];
        attribute elapsedRestTime : DurationValue = 0 [s];

        port controllerFeedback : FeedbackPort;
        port compressorCommand : CommandPort;
        port manifoldCommand : CommandPort;
        port safetyInput : SafetyCommandPort;

        action def ExecuteTherapyCycle {
            in feedback : PressureReading;
            out compressorCmd : ControlCommand;
            out manifoldCmd : ControlCommand;
        }

        perform action executeCycle : ExecuteTherapyCycle;

        state def ControllerBehavior {
            entry; then idle;

            state idle {
                entry { sessionActive = false; cycleComplete = false; }
            }

            state inflating {
                entry {
                    currentTherapyState = TherapyState::inflating;
                    compressorCommand.command.action = "inflate";
                    manifoldCommand.command.action = "inflate";
                    manifoldCommand.command.targetPressure = prescribedPressure;
                }
                do {
                    if currentChamber == ChamberPosition::distal {
                        manifoldCommand.command.targetChamber = "distal";
                    } else if currentChamber == ChamberPosition::middle {
                        manifoldCommand.command.targetChamber = "middle";
                    } else if currentChamber == ChamberPosition::proximal {
                        manifoldCommand.command.targetChamber = "proximal";
                    }

                    if controllerFeedback.reading.measuredPressure >= prescribedPressure {
                        if currentChamber == ChamberPosition::distal {
                            currentChamber = ChamberPosition::middle;
                        } else if currentChamber == ChamberPosition::middle {
                            currentChamber = ChamberPosition::proximal;
                        } else if currentChamber == ChamberPosition::proximal {
                            // all chambers inflated
                        }
                    }
                }
            }

            state holding {
                entry {
                    currentTherapyState = TherapyState::holding;
                    compressorCommand.command.action = "hold";
                    manifoldCommand.command.action = "hold";
                }
                do {
                    if controllerFeedback.reading.measuredPressure < (prescribedPressure - 5 [mmHg]) {
                        compressorCommand.command.action = "inflate";
                        manifoldCommand.command.action = "inflate";
                    }
                }
            }

            state deflating {
                entry {
                    currentTherapyState = TherapyState::deflating;
                    compressorCommand.command.action = "deflate";
                    manifoldCommand.command.action = "deflate";
                }
            }

            state resting {
                entry {
                    currentTherapyState = TherapyState::resting;
                    compressorCommand.command.action = "hold";
                    manifoldCommand.command.action = "hold";
                }
            }

            state emergencyShutdown {
                entry {
                    currentTherapyState = TherapyState::emergencyShutdown;
                    compressorCommand.command.action = "deflate";
                    manifoldCommand.command.action = "deflate";
                    sessionActive = false;
                }
            }

            transition idle_to_inflating
                first idle then inflating
                when sessionActive == true;

            transition inflating_to_holding
                first inflating then holding
                when currentChamber == ChamberPosition::proximal and
                     controllerFeedback.reading.measuredPressure >= prescribedPressure;

            transition holding_to_deflating
                first holding then deflating
                when elapsedHoldTime >= holdDuration;

            transition deflating_to_resting
                first deflating then resting
                when elapsedDeflationTime >= deflationDuration and
                     controllerFeedback.reading.measuredPressure <= 5 [mmHg];

            transition resting_to_inflating
                first resting then inflating
                when elapsedRestTime >= restDuration and sessionActive == true {
                    currentChamber = ChamberPosition::distal;
                    cycleComplete = true;
                }

            transition any_to_emergency
                first inflating then emergencyShutdown
                when safetyInput.alert.alertType == "overpressure";

            transition holding_to_emergency
                first holding then emergencyShutdown
                when safetyInput.alert.alertType == "overpressure";

            transition deflating_to_emergency
                first deflating then emergencyShutdown
                when safetyInput.alert.alertType == "overpressure";

            transition resting_to_emergency
                first resting then emergencyShutdown
                when safetyInput.alert.alertType == "overpressure";
        }

        exhibit state ControllerBehavior;
    }

    // ===== IPC System Assembly =====

    part def IPCSystem {
        attribute systemID : String = "IPC-001";
        attribute patientConnected : Boolean = false;
        attribute therapySessionDuration : DurationValue = 3600 [s];

        part controller : Controller;
        part compressor : AirCompressor;
        part manifold : ValveManifold;
        part sleeve : CompressionSleeve;
        part pressureSensor : PressureSensor;
        part safetyMonitor : SafetyMonitor;

        // Connections: Controller commands
        connection controllerToCompressor : > CommandPort connect controller.compressorCommand to compressor.compressorControl;
        connection controllerToManifold : > CommandPort connect controller.manifoldCommand to manifold.manifoldCommand;

        // Connections: Air flow
        connection compressorToManifold : > AirPort connect compressor.compressedAirOut to manifold.manifoldAirIn;
        connection manifoldToSleeveDistal : > AirPort connect manifold.manifoldAirOutDistal to sleeve.sleeveAirIn;
        connection manifoldToSleeveMiddle : > AirPort connect manifold.manifoldAirOutMiddle to sleeve.sleeveAirIn;
        connection manifoldToSleeveProximal : > AirPort connect manifold.manifoldAirOutProximal to sleeve.sleeveAirIn;

        // Connections: Pressure feedback
        connection sleeveToSensor : > AirPort connect sleeve.sleeveAirIn to pressureSensor.sensorInput;
        connection sensorToController : > FeedbackPort connect pressureSensor.sensorOutput to controller.controllerFeedback;
        connection sensorToSafety : > FeedbackPort connect pressureSensor.sensorOutput to safetyMonitor.safetyFeedback;

        // Connections: Safety
        connection safetyToController : > SafetyCommandPort connect safetyMonitor.safetyAlertPort to controller.safetyInput;

        // Requirements satisfaction
        satisfy therapyPressureReq : TherapyPressureRequirement by sleeve;
        satisfy sequentialInflationReq : SequentialInflationRequirement by controller;
        satisfy safetyShutdownReq : SafetyShutdownRequirement by safetyMonitor;
        satisfy cycleDurationReq : CycleDurationRequirement by controller;
    }

}
