package LUCAS_Model {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types with Units ----------
    value def Length_mm :> Real { unit = 'mm'; }
    value def Force_N :> Real { unit = 'N'; }
    value def Frequency_per_min :> Real { unit = '1/min'; }
    value def Duration_min :> Real { unit = 'min'; }
    value def Duration_s :> Real { unit = 's'; }
    value def ElectricPotential_V :> Real { unit = 'V'; }
    value def ElectricCurrent_A :> Real { unit = 'A'; }
    value def Power_W :> Real { unit = 'W'; }
    value def Energy_J :> Real { unit = 'J'; }
    value def Percent :> Real { unit = '%'; }
    value def BatterySOC :> Percent;
    value def CompressionDepth :> Length_mm;
    value def CompressionRate :> Frequency_per_min;
    value def AppliedForce :> Force_N;
    value def PistonStroke :> Length_mm;
    value def PistonVelocity :> Real { unit = 'mm/s'; }

    // ---------- Item Definitions ----------
    item def ElectricPower {
        ref voltage : ElectricPotential_V;
        ref current : ElectricCurrent_A;
        ref power : Power_W;
    }
    item def ControlCommand {
        kind : ControlCommandKind;
    }
    enum ControlCommandKind { on; standby; start; pause; resume; emergencyStop; lowPower; }
    item def SensorFeedback {
        measuredDepth : CompressionDepth;
        measuredForce : AppliedForce;
    }
    item def PistonMotion {
        stroke : PistonStroke;
        velocity : PistonVelocity;
    }
    item def ChestContactSignal {
        inContact : Boolean;
    }

    // ---------- Port Definitions ----------
    port def ElectricPowerPort {
        in power : ElectricPower;
    }
    port def BatteryOutputPort :> ElectricPowerPort;
    port def MotorPowerPort :> ElectricPowerPort;
    port def ProcessorPowerPort :> ElectricPowerPort;
    port def SensorReadPort {
        out feedback : SensorFeedback;
    }
    port def MotorControlPort {
        in torqueCommand : Real { unit = 'N*m'; }
        in enable : Boolean;
    }
    port def CommandInputPort {
        in command : ControlCommand;
    }
    port def MechanicalOutputPort {
        out motion : PistonMotion;
    }
    port def MechanicalInputPort {
        in motion : PistonMotion;
    }
    port def ChestInterfacePort {
        out compressionForce : AppliedForce;
        out liftForce : AppliedForce;
        in contactStatus : ChestContactSignal;
    }

    // ---------- Requirements ----------
    requirement def LUCAS_OverallRequirement {
        doc "The LUCAS shall provide continuous, consistent automated CPR to patients in cardiac arrest, adhering to medical guidelines, freeing medical personnel for other critical tasks.";
    }
    requirement def PortabilityRequirement {
        doc "The system shall be portable and battery-powered for rapid deployment in emergency situations.";
    }
    requirement def BatteryEnduranceRequirement {
        doc "The rechargeable Battery Pack shall provide power for at least 45 minutes of continuous operation.";
        subject batteryPack : BatteryPack;
        constraint { batteryPack.nominalEndurance >= 45 [Duration_min] }
    }
    requirement def CompressionDepthRequirement {
        doc "Each compression shall reach a target depth of 50 to 55 mm.";
        subject system : LUCASDevice;
        constraint { (50 [Length_mm] <= system.targetDepth) & (system.targetDepth <= 55 [Length_mm]) }
    }
    requirement def CompressionRateRequirement {
        doc "The compression rate shall be approximately 102 compressions per minute.";
        subject system : LUCASDevice;
        constraint { (100 [Frequency_per_min] <= system.targetRate) & (system.targetRate <= 104 [Frequency_per_min]) }
    }
    requirement def ChestRecoilRequirement {
        doc "The Suction Cup Assembly shall actively lift the chest during decompression to ensure full chest recoil.";
        subject suctionCup : SuctionCupAssembly;
        constraint { suctionCup.activeLift == true; }
    }
    requirement def ClosedLoopControlRequirement {
        doc "The Control Processor shall continuously monitor Depth and Force sensors and adjust compressions in real time to reach target depth and rate without excessive force.";
        subject controller : ControlProcessor;
        constraint { controller.closedLoopEnabled == true; }
        constraint { controller.maxAllowableForce == 600 [Force_N]; }
    }
    requirement def EmergencyStopRequirement {
        doc "The system shall provide an emergencyStop function that immediately halts the mechanism.";
        subject system : LUCASDevice;
        constraint { system.emergencyStopAvailable == true; }
    }
    requirement def LowBatteryWarningRequirement {
        doc "The system shall enter a lowBattery state to warn operators when remaining battery capacity is low.";
        subject system : LUCASDevice;
        constraint { system.lowBatteryThreshold == 20 [%]; }
    }

    // ---------- State Machines ----------
    state def LUCAS_OperatingStates {
        doc "Operating mode state machine for the LUCAS device.";

        entry;
        then off;

        state off {
            entry;
            exit;
        }
        transition t_off_to_standby from off to standby
            when powerOnSignal == true;
        transition t_off_to_lowBattery from off to lowBattery
            when battery.soc <= lowBatteryThreshold;
        state standby {
            entry;
            exit;
        }
        transition t_standby_to_active from standby to active
            when startSignal == true;
        transition t_standby_to_off from standby to off
            when powerOffSignal == true;
        state active {
            entry;
            exit;
        }
        transition t_active_to_paused from active to paused
            when pauseSignal == true;
        transition t_active_to_lowBattery from active to lowBattery
            when battery.soc <= lowBatteryThreshold;
        state paused {
            entry;
            exit;
        }
        transition t_paused_to_active from paused to active
            when resumeSignal == true;
        transition t_paused_to_off from paused to off
            when powerOffSignal == true;
        state lowBattery {
            entry;
            exit;
        }
        transition t_lowBattery_to_active from lowBattery to active
            when battery.soc > lowBatteryThreshold & startSignal == true;
        transition t_lowBattery_to_off from lowBattery to off
            when powerOffSignal == true;

        parallel emergencyHandling {
            state monitoring;
            state halted {
                entry { /* stop motor immediately */ }
            }
            transition t_any_to_halted from monitoring to halted
                when emergencyStopSignal == true;
            transition t_halted_to_off from halted to monitoring
                when powerOffSignal == true;
        }
    }

    // ---------- Control Algorithm ----------
    action def ControlLoopAction {
        in targetDepth : CompressionDepth;
        in targetRate : CompressionRate;
        in measuredDepth : CompressionDepth;
        in measuredForce : AppliedForce;
        in soc : BatterySOC;
        out torqueCommand : Real { unit = 'N*m'; }
        out enable : Boolean;
        out warning : Boolean;

        if measuredDepth < targetDepth {
            torqueCommand = 8.0;
        } else if measuredDepth > targetDepth {
            torqueCommand = -2.0;
        } else {
            torqueCommand = 0.0;
        }
        if measuredForce > 600 [Force_N] {
            torqueCommand = -3.0;
            enable = false;
        } else {
            enable = true;
        }
        warning = (soc <= 20 [%]);
    }

    action def CompressionCycleAction {
        in cycleTime : Duration_s;
        out currentStroke : PistonStroke;
        out currentVelocity : PistonVelocity;

        var phase : Real;
        phase = cycleTime % 0.588 [Duration_s];
        if phase < 0.294 [Duration_s] {
            currentVelocity = -180.0;
            currentStroke = phase * (-180.0);
        } else {
            currentVelocity = 180.0;
            currentStroke = (0.588 [Duration_s] - phase) * (-180.0);
        }
    }

    // ---------- Part Definitions ----------
    part def BatteryPack {
        attribute nominalVoltage : ElectricPotential_V = 24 [ElectricPotential_V];
        attribute capacity_Wh : Real = 720.0 { unit = 'W*h'; }
        attribute soc : BatterySOC;
        attribute nominalEndurance : Duration_min = 45 [Duration_min];
        attribute lowThreshold : BatterySOC = 20 [%];
        port batteryOut : BatteryOutputPort;
        action powerOutputBehavior {
            out power : ElectricPower;
            power.voltage = nominalVoltage;
            power.current = 4.0 [ElectricCurrent_A];
            power.power = nominalVoltage * power.current;
        }
    }

    part def ElectricMotor {
        attribute ratedPower : Power_W = 250 [Power_W];
        attribute maxTorque : Real = 12.0 { unit = 'N*m'; }
        port powerIn : MotorPowerPort;
        port controlIn : MotorControlPort;
        port shaftOut : MechanicalOutputPort;
        action motorBehavior {
            in enable : Boolean;
            in torqueCommand : Real { unit = 'N*m'; }
            out motion : PistonMotion;
            if enable == true {
                motion.velocity = torqueCommand * 15.0;
                motion.stroke = torqueCommand * 5.0;
            } else {
                motion.velocity = 0.0;
                motion.stroke = 0.0;
            }
        }
    }

    part def CompressionPiston {
        attribute maxStroke : PistonStroke = 60 [Length_mm];
        port mechanicalIn : MechanicalInputPort;
        port mechanicalOut : MechanicalOutputPort;
        action pistonTransmission {
            in inputMotion : PistonMotion;
            out outputMotion : PistonMotion;
            outputMotion.stroke = inputMotion.stroke * 1.0;
            outputMotion.velocity = inputMotion.velocity * 1.0;
        }
    }

    part def SuctionCupAssembly {
        attribute activeLift : Boolean = true;
        attribute cupDiameter : Length_mm = 130 [Length_mm];
        port mechanicalIn : MechanicalInputPort;
        port chestInterface : ChestInterfacePort;
        action cupBehavior {
            in inputMotion : PistonMotion;
            in contact : ChestContactSignal;
            out compressionForce : AppliedForce;
            out liftForce : AppliedForce;
            if inputMotion.velocity < 0.0 {
                compressionForce = 500 [Force_N];
                liftForce = 0 [Force_N];
            } else {
                compressionForce = 0 [Force_N];
                liftForce = 80 [Force_N];
            }
        }
    }

    part def DepthSensor {
        attribute accuracy : Length_mm = 1 [Length_mm];
        port readOut : SensorReadPort;
        action senseDepth {
            out depth : CompressionDepth;
            depth = 52 [Length_mm];
        }
    }

    part def ForceSensor {
        attribute range : Force_N = 1000 [Force_N];
        port readOut : SensorReadPort;
        action senseForce {
            out force : AppliedForce;
            force = 450 [Force_N];
        }
    }

    part def ControlProcessor {
        attribute closedLoopEnabled : Boolean = true;
        attribute maxAllowableForce : Force_N = 600 [Force_N];
        attribute targetDepth : CompressionDepth;
        attribute targetRate : CompressionRate;
        attribute lowBatteryThreshold : BatterySOC = 20 [%];
        port powerIn : ProcessorPowerPort;
        port commandIn : CommandInputPort;
        port depthSensorIn : SensorReadPort;
        port forceSensorIn : SensorReadPort;
        port batteryMonitorIn : ElectricPowerPort;
        port motorControlOut : MotorControlPort;
        action controlLoop : ControlLoopAction;
    }

    part def UserInterface {
        attribute buttonsEnabled : Boolean = true;
        port commandOut : CommandInputPort;
        action operatorInput {
            out cmd : ControlCommand;
        }
    }

    // ---------- Main System ----------
    part def LUCASDevice {
        attribute targetDepth : CompressionDepth = 52 [Length_mm];
        attribute targetRate : CompressionRate = 102 [Frequency_per_min];
        attribute lowBatteryThreshold : BatterySOC = 20 [%];
        attribute emergencyStopAvailable : Boolean = true;
        attribute lowBatteryThresholdValue1 : BatterySOC = 20 [%];

        // signals used by state machine
        attribute powerOnSignal : Boolean = false;
        attribute powerOffSignal : Boolean = false;
        attribute startSignal : Boolean = false;
        attribute pauseSignal : Boolean = false;
        attribute resumeSignal : Boolean = false;
        attribute emergencyStopSignal : Boolean = false;

        part battery : BatteryPack {
            redefines soc = 95 [%];
        }
        part motor : ElectricMotor;
        part controller : ControlProcessor {
            redefines targetDepth = 52 [Length_mm];
            redefines targetRate = 102 [Frequency_per_min];
        }
        part piston : CompressionPiston;
        part suctionCup : SuctionCupAssembly;
        part depthSensor : DepthSensor;
        part forceSensor : ForceSensor;
        part userInterface : UserInterface;

        state operatingState : LUCAS_OperatingStates;

        satisfy LUCAS_OverallRequirement;
        satisfy PortabilityRequirement;
        satisfy BatteryEnduranceRequirement by battery;
        satisfy CompressionDepthRequirement;
        satisfy CompressionRateRequirement;
        satisfy ChestRecoilRequirement by suctionCup;
        satisfy ClosedLoopControlRequirement by controller;
        satisfy EmergencyStopRequirement;
        satisfy LowBatteryWarningRequirement;

        connection batteryToMotor connect battery.batteryOut to motor.powerIn;
        connection batteryToController connect battery.batteryOut to controller.powerIn;
        connection batteryToProcessorMonitor connect battery.batteryOut to controller.batteryMonitorIn;
        connection controllerToMotor connect controller.motorControlOut to motor.controlIn;
        connection motorToPiston connect motor.shaftOut to piston.mechanicalIn;
        connection pistonToSuctionCup connect piston.mechanicalOut to suctionCup.mechanicalIn;
        connection depthSensorToController connect depthSensor.readOut to controller.depthSensorIn;
        connection forceSensorToController connect forceSensor.readOut to controller.forceSensorIn;
        connection uiToController connect userInterface.commandOut to controller.commandIn;

        connection suctionCupToPatient connect suctionCup.chestInterface;
    }

    // ---------- Requirement Group ----------
    requirement group LUCAS_Requirements {
        requirement overallReq : LUCAS_OverallRequirement;
        requirement portabilityReq : PortabilityRequirement;
        requirement enduranceReq : BatteryEnduranceRequirement;
        requirement depthReq : CompressionDepthRequirement;
        requirement rateReq : CompressionRateRequirement;
        requirement recoilReq : ChestRecoilRequirement;
        requirement controlReq : ClosedLoopControlRequirement;
        requirement estopReq : EmergencyStopRequirement;
        requirement lowBatReq : LowBatteryWarningRequirement;
    }

    // ---------- Instantiated System ----------
    part lucasInstance : LUCASDevice {
        part redefines battery {
            redefines soc = 95 [%];
        }
        part redefines controller {
            redefines targetDepth = 52 [Length_mm];
            redefines targetRate = 102 [Frequency_per_min];
        }
    }

}
