package FDM3DPrintingSystem {
    private import ScalarValues::*;

    attribute def Temperature :> Real;
    attribute def Length :> Real;
    attribute def Speed :> Real;
    attribute def RotationalSpeed :> Real;
    attribute def Percentage :> Real;

    enum def PrintStateKind {
        idle;
        homing;
        preheating;
        printing;
        coolingDown;
        completed;
        error;
    }

    item def PrintJobCommand {
        attribute start : Boolean;
        attribute pause : Boolean;
        attribute cancel : Boolean;
        attribute printComplete : Boolean;
        attribute filePath : String;
    }

    item def PrintStatus {
        attribute printState : PrintStateKind;
        attribute progress : Percentage;
        attribute statusMessage : String;
    }

    item def MotionCommand {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
        attribute feedRate : Speed;
    }

    item def MotionStatus {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
        attribute homed : Boolean;
    }

    item def ExtrusionCommand {
        attribute filamentFeedRate : Speed;
        attribute extruderSpeed : RotationalSpeed;
        attribute retractLength : Length;
    }

    item def FilamentStatus {
        attribute filamentPresent : Boolean;
        attribute remainingLength : Length;
    }

    item def TemperatureCommand {
        attribute targetTemperature : Temperature;
    }

    item def FanCommand {
        attribute speed : Percentage;
    }

    item def ExtrudedMaterial {
        attribute temperature : Temperature;
        attribute diameter : Length;
        attribute flowRate : Speed;
    }

    item def Filament {
        attribute diameter : Length;
        attribute materialType : String;
    }

    state machine def PrintProcessStateMachine {
        in command : PrintJobCommand;
        in motionStatus : MotionStatus;
        in hotendTemperature : Temperature;
        in bedTemperature : Temperature;
        in filamentStatus : FilamentStatus;
        out motionCommand : MotionCommand;
        out extrusionCommand : ExtrusionCommand;
        out hotendCommand : TemperatureCommand;
        out bedCommand : TemperatureCommand;
        out fanCommand : FanCommand;
        out displayStatus : PrintStatus;

        state idle;
        state homing;
        state preheating;
        state printing;
        state coolingDown;
        state completed;
        state error;

        transition t1 from idle to homing when command.start == true;
        transition t2 from homing to preheating when motionStatus.homed == true;
        transition t3 from preheating to printing when hotendTemperature >= 180 and bedTemperature >= 60;
        transition t4 from printing to coolingDown when command.cancel == true or command.printComplete == true;
        transition t5 from coolingDown to completed when hotendTemperature <= 40 and bedTemperature <= 40;
        transition t6 from printing to error when filamentStatus.filamentPresent == false;
    }

    part def Axis {
        port commandPort {
            in position : Length;
            in speed : Speed;
        }
        port statusPort {
            out position : Length;
            out homed : Boolean;
        }
    }

    part def MotionSystem {
        port commandPort {
            in command : MotionCommand;
        }
        port statusPort {
            out status : MotionStatus;
        }
        part xAxis : Axis;
        part yAxis : Axis;
        part zAxis : Axis;
    }

    part def StepperMotor {
        port speedCommandPort {
            in speed : RotationalSpeed;
        }
        port statusPort {
            out currentSpeed : RotationalSpeed;
        }
    }

    part def DriveGear {
        port inputSpeedPort {
            in speed : RotationalSpeed;
        }
        port filamentOutputPort {
            out filamentSpeed : Speed;
        }
    }

    part def FilamentSpool {
        port filamentSupplyPort {
            out filamentPresent : Boolean;
            out remainingLength : Length;
        }
    }

    part def ExtrusionSystem {
        port commandPort {
            in command : ExtrusionCommand;
        }
        port filamentStatusPort {
            out status : FilamentStatus;
        }
        port filamentOutputPort {
            out filamentSpeed : Speed;
        }
        part extruderMotor : StepperMotor;
        part driveGear : DriveGear;
        part filamentSpool : FilamentSpool;
    }

    part def HeatingElement {
        port commandPort {
            in command : TemperatureCommand;
        }
        port statusPort {
            out currentTemperature : Temperature;
        }
    }

    part def Thermistor {
        port temperatureOutPort {
            out currentTemperature : Temperature;
        }
    }

    part def Nozzle {
        port filamentInPort {
            in filamentSpeed : Speed;
        }
        port extrusionOutPort {
            out material : ExtrudedMaterial;
        }
        attribute diameter : Length = 0.4;
    }

    part def Hotend {
        port filamentInputPort {
            in filamentSpeed : Speed;
        }
        port temperatureCommandPort {
            in command : TemperatureCommand;
        }
        port temperatureStatusPort {
            out currentTemperature : Temperature;
        }
        port extrusionOutputPort {
            out material : ExtrudedMaterial;
        }
        part heatingElement : HeatingElement;
        part thermistor : Thermistor;
        part nozzle : Nozzle;

        bind temperatureCommandPort = heatingElement.commandPort;
        bind temperatureStatusPort = thermistor.temperatureOutPort;
        bind filamentInputPort = nozzle.filamentInPort;
        bind extrusionOutputPort = nozzle.extrusionOutPort;
    }

    part def HeatedBed {
        port temperatureCommandPort {
            in command : TemperatureCommand;
        }
        port temperatureStatusPort {
            out currentTemperature : Temperature;
        }
        port buildPlatformPort {
            in material : ExtrudedMaterial;
        }
        part bedHeatingElement : HeatingElement;
        part bedThermistor : Thermistor;

        bind temperatureCommandPort = bedHeatingElement.commandPort;
        bind temperatureStatusPort = bedThermistor.temperatureOutPort;

        attribute surfaceLength : Length = 220;
        attribute surfaceWidth : Length = 220;
    }

    part def CoolingFan {
        port commandPort {
            in command : FanCommand;
        }
        port statusPort {
            out actualSpeed : Percentage;
        }
    }

    part def Operator {
        port commandPort {
            out command : PrintJobCommand;
        }
        port statusPort {
            in status : PrintStatus;
        }
    }

    part def ControllerBoard {
        port userInputPort {
            in command : PrintJobCommand;
        }
        port userOutputPort {
            out status : PrintStatus;
        }
        port motionCommandPort {
            out command : MotionCommand;
        }
        port motionStatusPort {
            in status : MotionStatus;
        }
        port extrusionCommandPort {
            out command : ExtrusionCommand;
        }
        port filamentStatusPort {
            in status : FilamentStatus;
        }
        port hotendCommandPort {
            out command : TemperatureCommand;
        }
        port hotendStatusPort {
            in currentTemperature : Temperature;
        }
        port bedCommandPort {
            out command : TemperatureCommand;
        }
        port bedStatusPort {
            in currentTemperature : Temperature;
        }
        port fanCommandPort {
            out command : FanCommand;
        }
        port fanStatusPort {
            in actualSpeed : Percentage;
        }

        exhibit printProcess : PrintProcessStateMachine {
            in command = userInputPort.command;
            in motionStatus = motionStatusPort.status;
            in hotendTemperature = hotendStatusPort.currentTemperature;
            in bedTemperature = bedStatusPort.currentTemperature;
            in filamentStatus = filamentStatusPort.status;
            out motionCommand = motionCommandPort.command;
            out extrusionCommand = extrusionCommandPort.command;
            out hotendCommand = hotendCommandPort.command;
            out bedCommand = bedCommandPort.command;
            out fanCommand = fanCommandPort.command;
            out displayStatus = userOutputPort.status;
        }
    }

    part def FDMPrinter {
        part operator : Operator;
        part controllerBoard : ControllerBoard;
        part motionSystem : MotionSystem;
        part extrusionSystem : ExtrusionSystem;
        part hotend : Hotend;
        part heatedBed : HeatedBed;
        part coolingFan : CoolingFan;

        flow userCommandFlow of PrintJobCommand
            from operator.commandPort.command to controllerBoard.userInputPort.command;
        flow userStatusFlow of PrintStatus
            from controllerBoard.userOutputPort.status to operator.statusPort.status;

        flow motionCommandFlow of MotionCommand
            from controllerBoard.motionCommandPort.command to motionSystem.commandPort.command;
        flow motionStatusFlow of MotionStatus
            from motionSystem.statusPort.status to controllerBoard.motionStatusPort.status;

        flow extrusionCommandFlow of ExtrusionCommand
            from controllerBoard.extrusionCommandPort.command to extrusionSystem.commandPort.command;
        flow filamentStatusFlow of FilamentStatus
            from extrusionSystem.filamentStatusPort.status to controllerBoard.filamentStatusPort.status;

        flow hotendCommandFlow of TemperatureCommand
            from controllerBoard.hotendCommandPort.command to hotend.temperatureCommandPort.command;
        flow hotendStatusFlow of Temperature
            from hotend.temperatureStatusPort.currentTemperature to controllerBoard.hotendStatusPort.currentTemperature;

        flow bedCommandFlow of TemperatureCommand
            from controllerBoard.bedCommandPort.command to heatedBed.temperatureCommandPort.command;
        flow bedStatusFlow of Temperature
            from heatedBed.temperatureStatusPort.currentTemperature to controllerBoard.bedStatusPort.currentTemperature;

        flow fanCommandFlow of FanCommand
            from controllerBoard.fanCommandPort.command to coolingFan.commandPort.command;
        flow fanStatusFlow of Percentage
            from coolingFan.statusPort.actualSpeed to controllerBoard.fanStatusPort.actualSpeed;

        flow filamentFeedFlow of Speed
            from extrusionSystem.filamentOutputPort.filamentSpeed to hotend.filamentInputPort.filamentSpeed;
        flow materialDepositionFlow of ExtrudedMaterial
            from hotend.extrusionOutputPort.material to heatedBed.buildPlatformPort.material;
    }

    part printer : FDMPrinter;

    requirement FDMPrintingRequirement {
        doc /* The system shall fabricate parts by melting a thermoplastic filament and depositing it in successive layers. */
    }
    requirement MotionPrecisionRequirement {
        doc /* The motion system shall provide positioning precision of at least 0.1 mm. */
    }
    requirement TemperatureControlRequirement {
        doc /* The system shall control hotend and heated bed temperatures to material-specific setpoints. */
    }
    requirement MaterialCompatibilityRequirement {
        doc /* The system shall support materials such as PLA, ABS, and PETG. */
    }
}
