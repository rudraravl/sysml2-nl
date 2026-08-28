package FeedingTubeSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceAndTime::*;
    import ISQThermodynamics::*;

    // ===== Value Types =====
    value type Volume :> Real { unit "mL"; }
    value type FlowRate :> Real { unit "mL/h"; }
    value type PumpSpeed :> Real { unit "rpm"; }
    value type Pressure :> Real { unit "kPa"; }
    value type BubbleSize :> Real { unit "mm"; }
    value type Duration :> Real { unit "min"; }

    // ===== Item Types =====
    item def NutritionalFormula;
    item def Air;

    // ===== Port Definitions =====
    port def FluidPort {
        out item formula : NutritionalFormula;
        in item air : Air;
    }

    port def FlowRateSignal {
        attribute measuredFlow : FlowRate;
    }

    port def PressureSignal {
        attribute measuredPressure : Pressure;
    }

    port def AirDetectionSignal {
        attribute bubbleDetected : Boolean;
        attribute bubbleSize : BubbleSize;
    }

    port def PumpCommand {
        attribute command : PumpCommandKind;
        attribute speed : PumpSpeed;
    }

    enum def PumpCommandKind { start; stop; adjust; }

    port def UICommand {
        attribute prescribedFlowRate : FlowRate;
        attribute prescribedVolume : Volume;
        attribute startCommand : Boolean;
        attribute pauseCommand : Boolean;
        attribute stopCommand : Boolean;
    }

    port def AlarmSignal {
        attribute alarmType : AlarmKind;
        attribute active : Boolean;
    }

    enum def AlarmKind { none; occlusion; airInLine; flowError; complete; }

    // ===== Requirements =====
    requirement def ControlledDelivery {
        doc "The system shall deliver liquid nutritional formula at a prescribed flow rate."
        attribute prescribedFlowRate : FlowRate;
        attribute prescribedVolume : Volume;
        require deliveredVolume == prescribedVolume;
    }

    requirement def SafetyMonitoring {
        doc "The system shall stop the pump and enter an alarmed state upon detecting occlusion, air in line, or flow error."
    }

    requirement def PrimingBeforeDelivery {
        doc "The system shall prime the delivery tube to purge air before entering the delivering state."
    }

    requirement def CompletionNotification {
        doc "The system shall enter a completed state when the prescribed volume has been administered."
    }

    // ===== Part Definitions =====
    part def Reservoir {
        port outFlow : FluidPort;
        attribute remainingVolume : Volume := 1000 [mL];
        item storedFormula : NutritionalFormula;
    }

    part def DeliveryTube {
        port inFlow : FluidPort;
        port outFlow : FluidPort;
        attribute length : Real { unit "cm"; }
        attribute internalPressure : Pressure;
    }

    part def PrecisionPump {
        port inFlow : FluidPort;
        port outFlow : FluidPort;
        port in commandPort : PumpCommand;
        attribute currentSpeed : PumpSpeed := 0 [rpm];
        attribute maxSpeed : PumpSpeed := 120 [rpm];

        action def PumpCycle {
            in formula : NutritionalFormula;
            out delivered : NutritionalFormula;
        }

        perform action pumpCycle : PumpCycle;

        state def PumpOperation {
            entry; then Running;
            state Running;
            state Stopped;
            transition Running_to_Stopped first Running if commandPort.command == PumpCommandKind::stop then Stopped;
            transition Stopped_to_Running first Stopped if commandPort.command == PumpCommandKind::start then Running;
        }
    }

    part def FlowRateSensor {
        port inFlow : FluidPort;
        port out signalPort : FlowRateSignal;
        attribute measuredFlow : FlowRate;
        attribute tolerance : FlowRate := 5 [mL/h];

        action def MeasureFlow {
            in fluid : FluidPort;
            out reading : FlowRate;
        }

        perform action measure : MeasureFlow;
    }

    part def PressureSensor {
        port inFlow : FluidPort;
        port out signalPort : PressureSignal;
        attribute measuredPressure : Pressure;
        attribute safeThreshold : Pressure := 50 [kPa];

        action def MeasurePressure {
            in fluid : FluidPort;
            out reading : Pressure;
        }

        perform action measure : MeasurePressure;
    }

    part def AirDetector {
        port inFlow : FluidPort;
        port out signalPort : AirDetectionSignal;
        attribute bubbleDetected : Boolean := false;
        attribute bubbleSize : BubbleSize := 0 [mm];
        attribute maxAllowableBubble : BubbleSize := 0.5 [mm];

        action def DetectAir {
            in fluid : FluidPort;
            out detected : Boolean;
            out size : BubbleSize;
        }

        perform action detect : DetectAir;
    }

    part def UserInterface {
        port out commandPort : UICommand;
        port in alarmPort : AlarmSignal;
        attribute displayText : String;
        attribute keypadInput : String;

        action def AcceptPrescription {
            out flowRate : FlowRate;
            out volume : Volume;
        }

        perform action acceptPrescription : AcceptPrescription;
    }

    part def Controller {
        port in uiPort : UICommand;
        port out pumpPort : PumpCommand;
        port in flowPort : FlowRateSignal;
        port in pressurePort : PressureSignal;
        port in airPort : AirDetectionSignal;
        port out alarmPort : AlarmSignal;

        attribute prescribedFlowRate : FlowRate := 0 [mL/h];
        attribute prescribedVolume : Volume := 0 [mL];
        attribute deliveredVolume : Volume := 0 [mL];
        attribute currentFlowRate : FlowRate := 0 [mL/h];
        attribute currentPressure : Pressure := 0 [kPa];
        attribute airInLine : Boolean := false;
        attribute occlusionDetected : Boolean := false;
        attribute safePressureThreshold : Pressure := 50 [kPa];

        action def ComputePumpCommand {
            in flow : FlowRate;
            in pressure : Pressure;
            in air : Boolean;
            in prescribedFlow : FlowRate;
            in delivered : Volume;
            in prescribedVol : Volume;
            out command : PumpCommandKind;
            out speed : PumpSpeed;
            out alarm : AlarmKind;
        }

        perform action compute : ComputePumpCommand;

        state def ControllerStateMachine {
            entry; then Standby;

            state Standby {
                entry { deliveredVolume := 0 [mL]; }
            }

            state Priming {
                entry { pumpPort.command := PumpCommandKind::start; pumpPort.speed := 30 [rpm]; }
            }

            state Delivering {
                entry { pumpPort.command := PumpCommandKind::start; pumpPort.speed := prescribedFlowRate; }
            }

            state Paused {
                entry { pumpPort.command := PumpCommandKind::stop; }
            }

            state Alarmed {
                entry { pumpPort.command := PumpCommandKind::stop; alarmPort.alarmType := AlarmKind::occlusion; alarmPort.active := true; }
            }

            state Completed {
                entry { pumpPort.command := PumpCommandKind::stop; alarmPort.alarmType := AlarmKind::complete; alarmPort.active := true; }
            }

            transition Standby_to_Priming
                first Standby
                if uiPort.startCommand
                then Priming;

            transition Priming_to_Delivering
                first Priming
                if airPort.bubbleDetected == false
                then Delivering;

            transition Delivering_to_Paused
                first Delivering
                if uiPort.pauseCommand
                then Paused;

            transition Paused_to_Delivering
                first Paused
                if uiPort.startCommand
                then Delivering;

            transition Delivering_to_Alarmed_Occlusion
                first Delivering
                if pressurePort.measuredPressure > safePressureThreshold
                then Alarmed;

            transition Delivering_to_Alarmed_Air
                first Delivering
                if airPort.bubbleDetected == true
                then Alarmed;

            transition Delivering_to_Alarmed_Flow
                first Delivering
                if abs(flowPort.measuredFlow - prescribedFlowRate) > 10 [mL/h]
                then Alarmed;

            transition Delivering_to_Completed
                first Delivering
                if deliveredVolume >= prescribedVolume
                then Completed;

            transition Alarmed_to_Standby
                first Alarmed
                if uiPort.stopCommand
                then Standby;

            transition Completed_to_Standby
                first Completed
                if uiPort.stopCommand
                then Standby;
        }

        perform state behavior : ControllerStateMachine;
    }

    part def Patient {
        port inFlow : FluidPort;
        attribute receivedVolume : Volume := 0 [mL];
    }

    // ===== System Assembly =====
    part def FeedingTubeSystem {
        satisfy ControlledDelivery;
        satisfy SafetyMonitoring;
        satisfy PrimingBeforeDelivery;
        satisfy CompletionNotification;

        part reservoir : Reservoir;
        part pump : PrecisionPump;
        part deliveryTube : DeliveryTube;
        part flowRateSensor : FlowRateSensor;
        part pressureSensor : PressureSensor;
        part airDetector : AirDetector;
        part userInterface : UserInterface;
        part controller : Controller;
        part patient : Patient;

        connection reservoir.outFlow to pump.inFlow;
        connection pump.outFlow to deliveryTube.inFlow;
        connection deliveryTube.outFlow to patient.inFlow;

        connection flowRateSensor.inFlow to deliveryTube.outFlow;
        connection pressureSensor.inFlow to deliveryTube.inFlow;
        connection airDetector.inFlow to deliveryTube.outFlow;

        connection userInterface.commandPort to controller.uiPort;
        connection controller.pumpPort to pump.commandPort;
        connection flowRateSensor.signalPort to controller.flowPort;
        connection pressureSensor.signalPort to controller.pressurePort;
        connection airDetector.signalPort to controller.airPort;
        connection controller.alarmPort to userInterface.alarmPort;
    }
}
