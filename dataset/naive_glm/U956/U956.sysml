package FDM3DPrinter {
    import ScalarValues::*;

    // ===== Units =====
    package Units {
        unit mm;
        unit degC;
        unit mm_per_s;
        unit mm_per_s2;
        unit mm3_per_s;
        unit rpm;
        unit watt;
        unit volt;
        unit ampere;
        unit percent;
        unit gram;
        unit mm3;
        unit hertz;
        unit megabyte;
    }

    // ===== Value Types =====
    value type Length :> Real { unit = Units::mm; }
    value type Temperature :> Real { unit = Units::degC; }
    value type LinearSpeed :> Real { unit = Units::mm_per_s; }
    value type Acceleration :> Real { unit = Units::mm_per_s2; }
    value type VolumetricFlowRate :> Real { unit = Units::mm3_per_s; }
    value type AngularSpeed :> Real { unit = Units::rpm; }
    value type Power :> Real { unit = Units::watt; }
    value type Voltage :> Real { unit = Units::volt; }
    value type Current :> Real { unit = Units::ampere; }
    value type Percentage :> Real { unit = Units::percent; }
    value type Mass :> Real { unit = Units::gram; }
    value type Volume :> Real { unit = Units::mm3; }
    value type Frequency :> Real { unit = Units::hertz; }
    value type MemorySize :> Real { unit = Units::megabyte; }

    // ===== Enumerations =====
    enum MaterialType { PLA; ABS; PETG; }
    enum AxisId { X; Y; Z; }
    enum PrinterState { Off; Initializing; Homing; Preheating; Ready; Printing; CoolingDown; Idle; }
    enum CommandStatus { Accepted; Rejected; Completed; Failed; }
    enum PrintResult { Success; Failed; Aborted; }

    // ===== Item Definitions =====
    item def Filament {
        attribute material : MaterialType;
        attribute diameter : Length = 1.75;
        attribute density : Real = 0.00124;
    }

    item def GCodeCommand {
        attribute code : String;
        attribute params : String;
        attribute sequenceId : Integer;
    }

    item def StatusReport {
        attribute state : PrinterState;
        attribute progress : Percentage;
        attribute hotendTemp : Temperature;
        attribute bedTemp : Temperature;
        attribute layerIndex : Integer;
        attribute totalLayers : Integer;
    }

    item def MaterialProfile {
        attribute material : MaterialType;
        attribute hotendTarget : Temperature;
        attribute bedTarget : Temperature;
        attribute coolingFanSpeed : Percentage;
        attribute printSpeed : LinearSpeed;
    }

    item plaProfile : MaterialProfile {
        redefines material = MaterialType::PLA;
        redefines hotendTarget = 200;
        redefines bedTarget = 60;
        redefines coolingFanSpeed = 100;
        redefines printSpeed = 60;
    }

    item absProfile : MaterialProfile {
        redefines material = MaterialType::ABS;
        redefines hotendTarget = 240;
        redefines bedTarget = 100;
        redefines coolingFanSpeed = 30;
        redefines printSpeed = 50;
    }

    item petgProfile : MaterialProfile {
        redefines material = MaterialType::PETG;
        redefines hotendTarget = 230;
        redefines bedTarget = 80;
        redefines coolingFanSpeed = 50;
        redefines printSpeed = 40;
    }

    // ===== Interfaces =====
    interface def CommandLink {
        out command : GCodeCommand;
        in status : StatusReport;
    }

    interface def PowerLink {
        out voltage : Voltage;
        out current : Current;
    }

    interface def FilamentSupply {
        out filament : Filament;
    }

    interface def MotionCommand {
        out targetPosition : Length;
        out feedRate : LinearSpeed;
        out axisId : AxisId;
    }

    interface def ExtruderCommand {
        out feedRate : VolumetricFlowRate;
    }

    interface def HeaterCommand {
        out targetTemp : Temperature;
    }

    interface def FanCommand {
        out dutyCycle : Percentage;
    }

    interface def TemperatureFeedback {
        out measuredTemp : Temperature;
    }

    // ===== Part Definitions =====
    part def StepperMotor {
        port pwr : ~PowerLink;
        attribute stepsPerRev : Integer = 200;
        attribute ratedCurrent : Current = 1.5;
        attribute holdingTorque : Real = 0.4;
        attribute angularSpeed : AngularSpeed;
    }

    part def LinearAxis {
        attribute axisId : AxisId;
        attribute travel : Length;
        attribute maxSpeed : LinearSpeed;
        attribute maxAccel : Acceleration;
        attribute currentPosition : Length;
        attribute homed : Boolean = false;
        part motor : StepperMotor;
        port motionIn : ~MotionCommand;
        port pwr : ~PowerLink;
    }

    part def MotionSystem {
        port motionIn : ~MotionCommand;
        port pwr : ~PowerLink;
        part xAxis : LinearAxis {
            redefines axisId = AxisId::X;
            redefines travel = 300;
            redefines maxSpeed = 300;
            redefines maxAccel = 2000;
        }
        part yAxis : LinearAxis {
            redefines axisId = AxisId::Y;
            redefines travel = 300;
            redefines maxSpeed = 300;
            redefines maxAccel = 2000;
        }
        part zAxis : LinearAxis {
            redefines axisId = AxisId::Z;
            redefines travel = 400;
            redefines maxSpeed = 50;
            redefines maxAccel = 200;
        }
    }

    part def FilamentSpool {
        attribute material : MaterialType = MaterialType::PLA;
        attribute remainingMass : Mass = 1000;
        attribute spoolDiameter : Length = 200;
        port filamentOut : FilamentSupply;
    }

    part def ExtrusionSystem {
        port extruderCmd : ~ExtruderCommand;
        port filamentIn : ~FilamentSupply;
        port filamentOut : FilamentSupply;
        port pwr : ~PowerLink;
        part gearMotor : StepperMotor {
            redefines stepsPerRev = 400;
        }
        part driveGear {
            attribute gearDiameter : Length = 10;
            attribute teeth : Integer = 20;
        }
        attribute feedRate : VolumetricFlowRate;
        part spool : FilamentSpool;
    }

    part def HeatingElement {
        port heaterCmd : ~HeaterCommand;
        port pwr : ~PowerLink;
        attribute ratedPower : Power;
        attribute currentTemp : Temperature;
        attribute resistance : Real = 4.0;
    }

    part def TemperatureSensor {
        attribute reading : Temperature;
        attribute accuracy : Temperature = 0.5;
        port tempOut : TemperatureFeedback;
    }

    part def Nozzle {
        attribute diameter : Length = 0.4;
        attribute material : String = "Brass";
        port filamentIn : ~FilamentSupply;
        port extrudeOut : FilamentSupply;
    }

    part def Hotend {
        port filamentIn : ~FilamentSupply;
        port heaterCmd : ~HeaterCommand;
        port pwr : ~PowerLink;
        port tempFeedback : TemperatureFeedback;
        attribute targetTemp : Temperature;
        attribute currentTemp : Temperature;
        attribute maxTemp : Temperature = 280;
        part heater : HeatingElement {
            redefines ratedPower = 40;
        }
        part nozzle : Nozzle;
        part tempSensor : TemperatureSensor;
        part heatBreak {
            attribute length : Length = 20;
        }
    }

    part def HeatedBed {
        port heaterCmd : ~HeaterCommand;
        port pwr : ~PowerLink;
        port tempFeedback : TemperatureFeedback;
        attribute targetTemp : Temperature;
        attribute currentTemp : Temperature;
        attribute surfaceDimensions : Length = 310;
        attribute maxTemp : Temperature = 120;
        part bedHeater : HeatingElement {
            redefines ratedPower = 200;
        }
        part bedSensor : TemperatureSensor;
    }

    part def CoolingFan {
        port fanCmd : ~FanCommand;
        port pwr : ~PowerLink;
        attribute maxFlow : Real = 10;
        attribute dutyCycle : Percentage;
        attribute ratedVoltage : Voltage = 24;
    }

    part def PowerSupply {
        port pwrOut : PowerLink;
        attribute outputVoltage : Voltage = 24;
        attribute maxCurrent : Current = 15;
        attribute ratedPower : Power = 360;
    }

    part def UserInterface {
        port statusIn : ~CommandLink;
        attribute displayType : String = "LCD";
        attribute inputMethod : String = "RotaryEncoder";
    }

    part def ControllerBoard {
        port commandBus : CommandLink;
        port motionOut : MotionCommand;
        port extruderOut : ExtruderCommand;
        port hotendCmd : HeaterCommand;
        port bedCmd : HeaterCommand;
        port fanCmd : FanCommand;
        port uiLink : CommandLink;
        port pwr : ~PowerLink;
        attribute clockSpeed : Frequency = 120;
        attribute memory : MemorySize = 512;
        attribute activeProfile : MaterialProfile;
        attribute currentState : PrinterState = PrinterState::Off;
        attribute printProgress : Percentage = 0;
        attribute totalLayers : Integer;
        attribute currentLayer : Integer;
        part processor {
            attribute architecture : String = "ARM Cortex-M4";
        }
    }

    // ===== Actions =====
    action def InitializeSystem {
        in controller : ControllerBoard;
        out ready : Boolean;
        start;
        action resetController {
            assign controller.currentState = PrinterState::Initializing;
        }
        action loadFirmware;
        action selfTest;
        then assign ready = true;
    }

    action def HomeAxes {
        in motion : MotionSystem;
        out homed : Boolean;
        start;
        action homeX { assign motion.xAxis.homed = true; }
        action homeY { assign motion.yAxis.homed = true; }
        action homeZ { assign motion.zAxis.homed = true; }
        then assign homed = true;
    }

    action def Preheat {
        in hotend : Hotend;
        in bed : HeatedBed;
        in profile : MaterialProfile;
        out ready : Boolean;
        start;
        action setHotendTarget { assign hotend.targetTemp = profile.hotendTarget; }
        action setBedTarget { assign bed.targetTemp = profile.bedTarget; }
        action waitForTemps {
            decision hotend.currentTemp >= profile.hotendTarget and bed.currentTemp >= profile.bedTarget;
            then assign ready = true;
        }
    }

    action def PrintLayer {
        in controller : ControllerBoard;
        in motion : MotionSystem;
        in extrusion : ExtrusionSystem;
        in hotend : Hotend;
        in fan : CoolingFan;
        in layerIndex : Integer;
        out complete : Boolean;
        start;
        action tracePerimeter {
            assign motion.motionIn.feedRate = controller.activeProfile.printSpeed;
        }
        action infill;
        action advanceZ { assign motion.zAxis.currentPosition = motion.zAxis.currentPosition + 0.2; }
        then assign complete = true;
    }

    action def CoolDown {
        in hotend : Hotend;
        in bed : HeatedBed;
        in fan : CoolingFan;
        out safe : Boolean;
        start;
        action disableHeaters {
            assign hotend.targetTemp = 0;
            assign bed.targetTemp = 0;
        }
        action runFan { assign fan.dutyCycle = 100; }
        action waitForCool {
            decision hotend.currentTemp <= 50;
            then assign safe = true;
        }
    }

    // ===== State Machine =====
    state def PrinterStateMachine {
        entry; then off;

        state off {
            entry action { /* printer powered off */ }
        }

        transition power_on
            from off to initializing
            when powerOn;

        state initializing {
            entry action InitializeSystem;
            do InitializeSystem;
            then homing;
        }

        state homing {
            entry action HomeAxes;
            do HomeAxes;
            then preheating;
        }

        state preheating {
            entry action Preheat;
            do Preheat;
            then ready;
        }

        state ready {
            entry action { /* awaiting print command */ }
        }

        transition start_print
            from ready to printing
            when printRequested;

        state printing {
            entry action { assign controller.currentState = PrinterState::Printing; }
            do PrintLayer;
            transition print_complete
                from printing to coolingDown
                when currentLayer >= totalLayers;
            transition print_abort
                from printing to coolingDown
                when abortRequested;
        }

        state coolingDown {
            entry action CoolDown;
            do CoolDown;
            then idle;
        }

        state idle {
            entry action { assign controller.currentState = PrinterState::Idle; }
        }

        transition reset
            from idle to off
            when powerOff;
    }

    // ===== Top-Level Printer =====
    part def FDM3DPrinter {
        attribute model : String = "FDM-300";
        attribute buildVolume : Volume = 27000000;
        attribute supportedMaterials : MaterialType[3] = (MaterialType::PLA, MaterialType::ABS, MaterialType::PETG);

        part controller : ControllerBoard;
        part motion : MotionSystem;
        part extrusion : ExtrusionSystem;
        part hotend : Hotend;
        part heatedBed : HeatedBed;
        part coolingFan : CoolingFan;
        part powerSupply : PowerSupply;
        part ui : UserInterface;

        // Power distribution
        connection powerToController from powerSupply.pwrOut to controller.pwr;
        connection powerToMotion from powerSupply.pwrOut to motion.pwr;
        connection powerToExtrusion from powerSupply.pwrOut to extrusion.pwr;
        connection powerToHotend from powerSupply.pwrOut to hotend.pwr;
        connection powerToBed from powerSupply.pwrOut to heatedBed.pwr;
        connection powerToFan from powerSupply.pwrOut to coolingFan.pwr;

        // Command and control
        connection motionControl from controller.motionOut to motion.motionIn;
        connection extruderControl from controller.extruderOut to extrusion.extruderCmd;
        connection hotendControl from controller.hotendCmd to hotend.heaterCmd;
        connection bedControl from controller.bedCmd to heatedBed.heaterCmd;
        connection fanControl from controller.fanCmd to coolingFan.fanCmd;

        // Material flow
        connection filamentFeed from extrusion.filamentOut to hotend.filamentIn;

        // Feedback
        connection hotendTempFeedback from hotend.tempFeedback to controller.commandBus;
        connection bedTempFeedback from heatedBed.tempFeedback to controller.commandBus;
        connection uiLink from controller.uiLink to ui.statusIn;

        // Behavior
        part printerBehavior : PrinterStateMachine;

        // Events
        occurrence powerOn;
        occurrence powerOff;
        occurrence printRequested;
        occurrence abortRequested;
    }

    // ===== Requirements =====
    package Requirements {
        import FDM3DPrinter::*;

        requirement def SystemRequirement {
            attribute id : String;
            attribute text : String;
        }

        requirement FunctionalFabrication : SystemRequirement {
            redefines id = "REQ-001";
            redefines text = "The system shall fabricate physical objects by melting thermoplastic filament and depositing it in successive layers.";
        }

        requirement ControllerOrchestration : SystemRequirement {
            redefines id = "REQ-002";
            redefines text = "The Controller Board shall process digital model files and send coordinated commands to all subsystems.";
        }

        requirement MotionPrecision : SystemRequirement {
            redefines id = "REQ-003";
            redefines text = "The Motion System shall position the print head with precision across X, Y, and Z axes.";
            attribute positioningAccuracy : Length = 0.1;
        }

        requirement ExtrusionControl : SystemRequirement {
            redefines id = "REQ-004";
            redefines text = "The Extrusion System shall feed filament to the hotend at a controlled volumetric rate.";
            attribute feedRateRange : VolumetricFlowRate = 5.0;
        }

        requirement HotendMelting : SystemRequirement {
            redefines id = "REQ-005";
            redefines text = "The Hotend shall melt incoming filament to a precise target temperature before extrusion.";
            attribute tempAccuracy : Temperature = 1.0;
            attribute maxTemp : Temperature = 280;
        }

        requirement HeatedBedAdhesion : SystemRequirement {
            redefines id = "REQ-006";
            redefines text = "The Heated Bed shall maintain a constant warm temperature to prevent warping.";
            attribute tempStability : Temperature = 2.0;
        }

        requirement CoolingAirflow : SystemRequirement {
            redefines id = "REQ-007";
            redefines text = "The Cooling Fan shall provide directed airflow to solidify freshly deposited plastic.";
            attribute minDutyCycle : Percentage = 30;
        }

        requirement MaterialCompatibility : SystemRequirement {
            redefines id = "REQ-008";
            redefines text = "The system shall support PLA, ABS, and PETG materials with distinct temperature profiles.";
        }

        requirement ProcessSequence : SystemRequirement {
            redefines id = "REQ-009";
            redefines text = "The printing process shall initialize, home axes, preheat, print layer by layer, and cool down before part removal.";
        }

        requirement SafetyCooldown : SystemRequirement {
            redefines id = "REQ-010";
            redefines text = "The system shall cool the hotend below 50 degC before indicating safe part removal.";
            attribute safeTemp : Temperature = 50;
        }

        requirement FDMSystemRequirements {
            satisfy FunctionalFabrication;
            satisfy ControllerOrchestration;
            satisfy MotionPrecision;
            satisfy ExtrusionControl;
            satisfy HotendMelting;
            satisfy HeatedBedAdhesion;
            satisfy CoolingAirflow;
            satisfy MaterialCompatibility;
            satisfy ProcessSequence;
            satisfy SafetyCooldown;
        }
    }
}
