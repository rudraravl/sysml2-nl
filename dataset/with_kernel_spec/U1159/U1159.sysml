package ArtificialPancreas {
    private import ScalarValues::*;
    private import ISQ::*;

    value type GlucoseLevel :> Real;
    value type InsulinDose :> Real;
    value type Weight :> Real;
    value type InsulinSensitivity :> Real;

    attribute def Tick;
    attribute def TurnOn;
    attribute def StartClosedLoop;
    attribute def LowGlucose;
    attribute def CriticalEvent;
    attribute def GlucoseNormal;
    attribute def Acknowledge;

    attribute def GlucoseReading {
        attribute level : GlucoseLevel;
        attribute timestamp : String;
    }
    attribute def InsulinCommand {
        attribute dose : InsulinDose;
    }
    attribute def MealInfo {
        attribute carbs : Real;
    }
    attribute def BolusCommand {
        attribute dose : InsulinDose;
    }
    attribute def SystemStatus {
        attribute glucose : GlucoseLevel;
        attribute activeInsulin : InsulinDose;
    }
    attribute def AlarmEvent {
        attribute type : String;
    }

    port def GlucoseOutPort {
        out reading : GlucoseReading;
    }
    port def GlucoseInPort {
        in reading : GlucoseReading;
    }
    port def CommandOutPort {
        out command : InsulinCommand;
    }
    port def CommandInPort {
        in command : InsulinCommand;
    }
    port def UIOutPort {
        out status : SystemStatus;
        out alarm : AlarmEvent;
    }
    port def UIInPort {
        in status : SystemStatus;
        in alarm : AlarmEvent;
    }
    port def UserInputOutPort {
        out meal : MealInfo;
        out bolus : BolusCommand;
    }
    port def UserInputInPort {
        in meal : MealInfo;
        in bolus : BolusCommand;
    }

    action def CalculateDose {
        in glucose : GlucoseLevel;
        out dose : InsulinDose;
    }
    action def DeliverInsulin {
        in dose : InsulinDose;
    }
    action def PredictGlucose {
        in current : GlucoseLevel;
        out predicted : GlucoseLevel;
    }

    part def ContinuousGlucoseMonitor {
        part sensor {
            out rawMeasurement : GlucoseReading;
        }
        part transmitter {
            in rawMeasurement : GlucoseReading;
            out reading : GlucoseReading;
        }
        flow of GlucoseReading from sensor.rawMeasurement to transmitter.rawMeasurement;
        port glucoseOut : GlucoseOutPort;
        bind glucoseOut.reading = transmitter.reading;

        exhibit state CGMStates {
            entry; then Measuring;
            state Measuring;
            accept Tick
            do send new GlucoseReading() via glucoseOut
            then Measuring;
        }
    }

    part def InsulinPump {
        part reservoir {
            attribute remainingInsulin : InsulinDose;
        }
        part motor {
            in command : InsulinCommand;
        }
        port commandIn : CommandInPort;
        bind commandIn.command = motor.command;

        exhibit state PumpStates {
            entry; then Idle;
            state Idle;
            accept cmd : InsulinCommand via commandIn
            do action DeliverInsulin { in dose = cmd.dose; }
            then Idle;
        }
    }

    part def ControlAlgorithm {
        port glucoseIn : GlucoseInPort;
        port commandOut : CommandOutPort;
        port uiOut : UIOutPort;
        port userInputIn : UserInputInPort;

        attribute targetMin : GlucoseLevel = 70;
        attribute targetMax : GlucoseLevel = 180;
        attribute maxActiveInsulin : InsulinDose = 10;
        attribute activeInsulin : InsulinDose = 0;

        exhibit state AlgorithmStates {
            entry; then Processing;
            state Processing;
            accept reading : GlucoseReading via glucoseIn
            do action {
                first start;
                then action PredictGlucose { in current = reading.level; out predicted; }
                then action CalculateDose { in glucose = reading.level; out dose; }
                then send new InsulinCommand(dose) via commandOut;
            }
            then Processing;
        }
    }

    part def UserInterface {
        port uiIn : UIInPort;
        port userInputOut : UserInputOutPort;

        exhibit state UIStates {
            entry; then Displaying;
            state Displaying;
            accept status : SystemStatus via uiIn
            then Displaying;
        }
    }

    part def Patient {
        attribute weight : Weight;
        attribute insulinSensitivity : InsulinSensitivity;
    }

    part def ArtificialPancreasSystem {
        part cgm : ContinuousGlucoseMonitor;
        part pump : InsulinPump;
        part controller : ControlAlgorithm;
        part ui : UserInterface;
        part patient : Patient;

        interface cgmToController connect cgm.glucoseOut to controller.glucoseIn {
            flow glucoseFlow of GlucoseReading from cgm.glucoseOut.reading to controller.glucoseIn.reading;
        }
        interface controllerToPump connect controller.commandOut to pump.commandIn {
            flow commandFlow of InsulinCommand from controller.commandOut.command to pump.commandIn.command;
        }
        interface controllerToUI connect controller.uiOut to ui.uiIn {
            flow statusFlow of SystemStatus from controller.uiOut.status to ui.uiIn.status;
            flow alarmFlow of AlarmEvent from controller.uiOut.alarm to ui.uiIn.alarm;
        }
        interface uiToController connect ui.userInputOut to controller.userInputIn {
            flow mealFlow of MealInfo from ui.userInputOut.meal to controller.userInputIn.meal;
            flow bolusFlow of BolusCommand from ui.userInputOut.bolus to controller.userInputIn.bolus;
        }

        exhibit state SystemStates {
            entry; then off;
            state off;
            accept TurnOn then manual;
            state manual;
            accept StartClosedLoop then closedLoop;
            state closedLoop;
            accept LowGlucose then suspend;
            accept CriticalEvent then alarm;
            state suspend;
            accept GlucoseNormal then closedLoop;
            state alarm;
            accept Acknowledge then manual;
        }
    }

    requirement def ClosedLoopControlRequirement {
        doc /* The system shall automatically adjust insulin delivery to maintain glucose within target range. */
        subject system : ArtificialPancreasSystem;
    }

    requirement closedLoopReq : ClosedLoopControlRequirement {
        doc /* The system shall operate in closedLoop mode to maintain glucose between 70 and 180 mg/dL. */
    }

    requirement def SafetyRequirement {
        doc /* The system shall prevent over-delivery of insulin. */
        subject system : ArtificialPancreasSystem;
    }

    requirement safetyReq : SafetyRequirement {
        doc /* The system shall not exceed the maximum active insulin limit. */
    }

    requirement def SuspendOnLowRequirement {
        doc /* The system shall suspend insulin delivery when glucose is low or predicted to drop below threshold. */
        subject system : ArtificialPancreasSystem;
    }

    requirement suspendReq : SuspendOnLowRequirement {
        doc /* The system shall enter suspend mode when glucose falls below 70 mg/dL. */
    }

    part artificialPancreas : ArtificialPancreasSystem {
        satisfy closedLoopReq;
        satisfy safetyReq;
        satisfy suspendReq;
    }
}
