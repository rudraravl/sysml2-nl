package Cytocentrifuge {

    import ScalarValues::*;

    // ---- Value types with units ----
    value def RotationalSpeed :> Real { unit 'rpm'; }
    value def Duration :> Real { unit 's'; }
    value def VibrationLevel :> Real { unit 'mm/s'; }
    value def Volume :> Real { unit 'mL'; }
    value def Area :> Real { unit 'mm2'; }
    value def Force :> Real { unit 'N'; }
    value def Mass :> Real { unit 'g'; }
    value def PoreSize :> Real { unit 'um'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Power :> Real { unit 'W'; }
    value def Pressure :> Real { unit 'Pa'; }

    // ---- Enumerations ----
    enumeration SpeedMode { low; medium; high; }
    enumeration LidState { open; closed; locked; }
    enumeration BalanceState { balanced; unbalanced; }
    enumeration CyclePhase { idle; loading; accelerating; spinning; decelerating; complete; }

    // ---- Item definitions ----
    item def BiologicalSample {
        attribute volume : Volume := 0.5 [mL];
        attribute cellCount : Integer;
        attribute sourceId : String;
    }

    item def FluidPassage :> BiologicalSample {
        attribute filtered : Boolean := false;
    }

    item def MicroscopeSlide {
        attribute slideArea : Area := 75 [mm2];
        attribute thickness : Real;
    }

    item def PreparedSlide :> MicroscopeSlide {
        attribute cellDensity : Real;
        attribute monolayerUniformity : Real;
        attribute readyForStaining : Boolean := false;
    }

    item def AbsorbentPad {
        attribute capacity : Volume := 4 [mL];
        attribute absorbedVolume : Volume := 0 [mL];
    }

    // ---- Port definitions ----
    port def MechanicalDrivePort {
        attribute torque : Real;
        attribute speed : RotationalSpeed;
    }

    port def ElectricalPowerPort {
        attribute voltage : Real;
        attribute current : Real;
        attribute power : Power;
    }

    port def ControlSignalPort {
        attribute command : String;
        attribute setpoint : RotationalSpeed;
        attribute duration : Duration;
    }

    port def SensorSignalPort {
        attribute vibration : VibrationLevel;
        attribute lidLocked : Boolean;
        attribute balanced : Boolean;
        attribute currentSpeed : RotationalSpeed;
    }

    port def FluidPort {
        item biologicalSample : BiologicalSample;
        item fluidPassage : FluidPassage;
    }

    port def UserCommandPort {
        attribute selectedMode : SpeedMode;
        attribute startRequested : Boolean;
        attribute stopRequested : Boolean;
    }

    port def SlideTransferPort {
        item preparedSlide : PreparedSlide;
    }

    // ---- Part definitions ----
    part def FilterCard {
        attribute poreSize : PoreSize := 8 [um];
        attribute membraneArea : Area := 50 [mm2];
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def SlideCarrier {
        part slide : MicroscopeSlide;
        port slideAccess : SlideTransferPort;
    }

    part def SampleChamber {
        item sample : BiologicalSample;
        part filterCard : FilterCard;
        part slideCarrier : SlideCarrier;
        part absorbentPad : AbsorbentPad;
        attribute chamberId : Integer;
        attribute loaded : Boolean := false;
        port sampleInput : FluidPort;
        port slideOutput : SlideTransferPort;

        action def FilterSample {
            in sampleIn : BiologicalSample;
            out preparedSlideOut : PreparedSlide;
            out absorbedFluid : FluidPassage;
        }
    }

    part def RotorAssembly {
        attribute maxChambers : Integer := 12;
        part sampleChambers : SampleChamber[0..12];
        attribute currentLoad : Integer;
        attribute balanced : Boolean := true;
        port driveInput : MechanicalDrivePort;
        port chamberAccess : SlideTransferPort;

        action def SpinChambers {
            in speed : RotationalSpeed;
            in duration : Duration;
            out preparedSlides : PreparedSlide[0..12];
        }
    }

    part def DriveMotor {
        attribute maxSpeed : RotationalSpeed := 2000 [rpm];
        attribute ratedPower : Power := 250 [W];
        attribute currentSpeed : RotationalSpeed := 0 [rpm];
        attribute targetSpeed : RotationalSpeed;
        port powerIn : ElectricalPowerPort;
        port driveOutput : MechanicalDrivePort;
        port controlIn : ControlSignalPort;

        action def Accelerate {
            in target : RotationalSpeed;
            in rampTime : Duration;
            update currentSpeed;
        }

        action def Decelerate {
            in rampTime : Duration;
            update currentSpeed;
        }
    }

    part def VibrationSensor {
        attribute threshold : VibrationLevel := 5 [mm/s];
        attribute currentReading : VibrationLevel := 0 [mm/s];
        port sensorOut : SensorSignalPort;
    }

    part def LidLockMechanism {
        attribute lidState : LidState := open;
        attribute lockEngaged : Boolean := false;
        port sensorOut : SensorSignalPort;
    }

    part def BalanceDetector {
        attribute balanceState : BalanceState := balanced;
        port sensorOut : SensorSignalPort;
    }

    part def EmergencyStopButton {
        attribute pressed : Boolean := false;
        port signalOut : SensorSignalPort;
    }

    part def SafetySystem {
        part lidLock : LidLockMechanism;
        part vibrationSensor : VibrationSensor;
        part balanceDetector : BalanceDetector;
        part eStop : EmergencyStopButton;
        attribute safetyClear : Boolean := false;
        port safetyStatus : SensorSignalPort;
        port motorCutoff : ControlSignalPort;

        action def EvaluateSafety {
            in lidLocked : Boolean;
            in balanced : Boolean;
            in vibration : VibrationLevel;
            in eStopPressed : Boolean;
            out clear : Boolean;
        }
    }

    part def UserPanel {
        attribute selectedMode : SpeedMode := low;
        attribute startRequested : Boolean := false;
        attribute stopRequested : Boolean := false;
        port userCommand : UserCommandPort;
        port displayOut : ControlSignalPort;
    }

    part def ControllerUnit {
        attribute cyclePhase : CyclePhase := idle;
        attribute targetSpeed : RotationalSpeed;
        attribute spinDuration : Duration := 300 [s];
        attribute speedMap : SpeedMode >> RotationalSpeed = (low -> 500 [rpm], medium -> 1000 [rpm], high -> 1500 [rpm]);
        port panelIn : UserCommandPort;
        port motorControl : ControlSignalPort;
        port safetyIn : SensorSignalPort;
        port rotorFeedback : SensorSignalPort;

        action def RunCycle {
            in mode : SpeedMode;
            in duration : Duration;
        }

        state def ControlStateMachine {
            entry action { cyclePhase := idle; }

            state idle {
                entry action { targetSpeed := 0 [rpm]; }
            }

            state loading {
                entry action { cyclePhase := loading; }
            }

            state accelerating {
                entry action { cyclePhase := accelerating; }
            }

            state spinning {
                entry action { cyclePhase := spinning; }
            }

            state decelerating {
                entry action { cyclePhase := decelerating; }
            }

            state complete {
                entry action { cyclePhase := complete; }
            }

            transition initial -> idle;
            transition idle -> loading
                when panelIn.startRequested && safetyIn.lidLocked;
            transition loading -> accelerating
                when rotorFeedback.balanced && safetyIn.lidLocked;
            transition accelerating -> spinning
                when rotorFeedback.currentSpeed >= targetSpeed;
            transition spinning -> decelerating
                when spinDuration == 0 [s] || panelIn.stopRequested;
            transition decelerating -> complete
                when rotorFeedback.currentSpeed == 0 [rpm];
            transition complete -> idle
                when !panelIn.startRequested;
            transition [accelerating, spinning, decelerating] -> decelerating
                when safetyIn.vibration > 5 [mm/s] || safetyIn.eStopPressed;
        }
    }

    // ---- Top-level system ----
    part def CytocentrifugeSystem {
        part controller : ControllerUnit;
        part motor : DriveMotor;
        part rotor : RotorAssembly;
        part panel : UserPanel;
        part safety : SafetySystem;

        connect controller.motorControl to motor.controlIn;
        connect motor.driveOutput to rotor.driveInput;
        connect panel.userCommand to controller.panelIn;
        connect safety.safetyStatus to controller.safetyIn;
        connect safety.motorCutoff to motor.controlIn;
        connect rotor.chamberAccess to panel.displayOut;

        attribute systemReady : Boolean := false;
        attribute processedSlides : Integer := 0;
    }

    // ---- Requirements ----
    requirement def ConcentrateCellsRequirement {
        subject system : CytocentrifugeSystem;
        objective {
            doc "The system shall concentrate cells from a low-cell-count liquid biological sample onto a defined area of a microscope slide, forming a thin, uniform monolayer."
        }
    }

    requirement def ThroughputRequirement {
        subject system : CytocentrifugeSystem;
        attribute maxChambers : Integer := 12;
        objective {
            doc "The rotor assembly shall hold and process up to 12 sample chambers simultaneously."
        }
    }

    requirement def SpeedControlRequirement {
        subject system : CytocentrifugeSystem;
        attribute lowSpeed : RotationalSpeed := 500 [rpm];
        attribute mediumSpeed : RotationalSpeed := 1000 [rpm];
        attribute highSpeed : RotationalSpeed := 1500 [rpm];
        objective {
            doc "The user shall select from low, medium, or high speed modes, and the motor shall accelerate the rotor to the corresponding precise rotational speed."
        }
    }

    requirement def FiltrationRequirement {
        subject filterCard : FilterCard;
        attribute poreSize : PoreSize := 8 [um];
        objective {
            doc "The filter card membrane shall allow fluid to pass through to the absorbent pad while trapping cells and depositing them onto the adjacent microscope slide."
        }
    }

    requirement def SafetyRequirement {
        subject safety : SafetySystem;
        attribute vibrationThreshold : VibrationLevel := 5 [mm/s];
        objective {
            doc "The safety system shall prevent operation unless the lid is locked and the rotor is balanced, shall continuously monitor vibration, and shall provide an emergency stop that halts the motor."
        }
    }

    requirement def CycleSequenceRequirement {
        subject controller : ControllerUnit;
        objective {
            doc "The controller shall sequence the cycle through idle, loading, accelerating, spinning, decelerating, and complete states."
        }
    }

    requirement def SlideQualityRequirement {
        subject slide : PreparedSlide;
        attribute minUniformity : Real := 0.9;
        objective {
            doc "Each prepared slide shall contain a high-quality monolayer of cells suitable for staining and diagnostic analysis."
        }
    }

    requirement def SpinDurationRequirement {
        subject controller : ControllerUnit;
        attribute defaultDuration : Duration := 300 [s];
        objective {
            doc "The spinning phase shall last for a user-defined duration, defaulting to 300 seconds."
        }
    }

    // ---- Requirement satisfaction ----
    satisfaction ConcentrateCellsRequirement {
        subject :>> system;
    }

    satisfaction ThroughputRequirement {
        subject :>> system;
    }

    satisfaction SafetyRequirement {
        subject :>> safety;
    }

    satisfaction CycleSequenceRequirement {
        subject :>> controller;
    }

}
