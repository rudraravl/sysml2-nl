package AutonomousLawnMowerSystem {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type Percent :> Real { unit "%"; min 0; max 100; }
    value type Distance :> Real { unit "m"; }
    value type Speed :> Real { unit "m/s"; }
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "A"; }
    value type AngularVelocity :> Real { unit "rad/s"; }
    value type Angle :> Real { unit "deg"; }
    value type GrassHeight :> Real { unit "mm"; }
    value type RotationalSpeed :> Real { unit "rpm"; }
    value type Power :> Real { unit "W"; }
    value type TimeValue :> Real { unit "s"; }
    value type Mass :> Real { unit "kg"; }
    value type Energy :> Real { unit "Wh"; }
    value type Area :> Real { unit "m^2"; }
    value type Frequency :> Real { unit "Hz"; }
    value type SignalStrength :> Real { unit "dB"; }

    // ===== Enumerations =====
    enum def OperationalMode {
        off;
        idle;
        mowing;
        obstacleAvoidance;
        boundaryTurn;
        navigatingToDock;
        docking;
        charging;
    }

    enum def ObstacleType {
        none;
        static;
        dynamic;
        boundary;
    }

    enum def TurnDirection {
        left;
        right;
        around;
    }

    enum def DriveDirection {
        forward;
        backward;
        stopped;
    }

    enum def BladeStatus {
        spinning;
        stopped;
    }

    enum def ChargingStatus {
        notCharging;
        charging;
        fullyCharged;
    }

    // ===== Item Definitions =====
    item def ObstacleDetection {
        attribute detected : Boolean;
        attribute distance : Distance;
        attribute type : ObstacleType;
    }

    item def BoundarySignal {
        attribute detected : Boolean;
        attribute signalStrength : SignalStrength;
    }

    item def BumpEvent {
        attribute triggered : Boolean;
        attribute timestamp : TimeValue;
    }

    item def GrassHeightReading {
        attribute height : GrassHeight;
        attribute uniform : Boolean;
    }

    item def BatteryStatus {
        attribute chargeLevel : Percent;
        attribute voltage : Voltage;
        attribute charging : Boolean;
    }

    item def DriveCommand {
        attribute leftWheelSpeed : AngularVelocity;
        attribute rightWheelSpeed : AngularVelocity;
        attribute direction : DriveDirection;
    }

    item def BladeCommand {
        attribute status : BladeStatus;
        attribute heightSetting : GrassHeight;
    }

    item def DockingBeaconSignal {
        attribute detected : Boolean;
        attribute direction : Angle;
        attribute distance : Distance;
    }

    item def PowerFlow {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def NavigationPlan {
        attribute targetHeading : Angle;
        attribute targetSpeed : Speed;
        attribute mode : OperationalMode;
    }

    // ===== Port Definitions =====
    port def PowerOutPort {
        out power : PowerFlow;
    }

    port def PowerInPort {
        in power : PowerFlow;
    }

    port def DockingPort {
        in out charge : PowerFlow;
    }

    port def ObstacleOutPort {
        out data : ObstacleDetection;
    }

    port def ObstacleInPort {
        in data : ObstacleDetection;
    }

    port def BoundaryOutPort {
        out data : BoundarySignal;
    }

    port def BoundaryInPort {
        in data : BoundarySignal;
    }

    port def BumpOutPort {
        out data : BumpEvent;
    }

    port def BumpInPort {
        in data : BumpEvent;
    }

    port def GrassHeightOutPort {
        out data : GrassHeightReading;
    }

    port def GrassHeightInPort {
        in data : GrassHeightReading;
    }

    port def BatteryStatusOutPort {
        out status : BatteryStatus;
    }

    port def BatteryStatusInPort {
        in status : BatteryStatus;
    }

    port def DriveCmdOutPort {
        out cmd : DriveCommand;
    }

    port def DriveCmdInPort {
        in cmd : DriveCommand;
    }

    port def BladeCmdOutPort {
        out cmd : BladeCommand;
    }

    port def BladeCmdInPort {
        in cmd : BladeCommand;
    }

    port def BeaconOutPort {
        out beacon : DockingBeaconSignal;
    }

    port def BeaconInPort {
        in beacon : DockingBeaconSignal;
    }

    // ===== Simple Action Definitions =====
    action def PowerOffSystems {
        doc "Power off all mower systems.";
    }

    action def InitializeSystems {
        doc "Initialize all mower systems for operation.";
        out ready : Boolean;
    }

    action def WaitForCommand {
        doc "Wait for mowing start command.";
        out commandReceived : Boolean;
    }

    action def StartBlades {
        doc "Start the cutting blades spinning.";
        out bladeCmd : BladeCommand;
    }

    action def StopBlades {
        doc "Stop the cutting blades.";
        out bladeCmd : BladeCommand;
    }

    action def StopMower {
        doc "Stop the mower's forward movement.";
        out driveCmd : DriveCommand;
    }

    action def PerformDocking {
        doc "Align and connect with the charging dock.";
        in beaconSignal : DockingBeaconSignal;
        out driveCmd : DriveCommand;
        out docked : Boolean;
    }

    action def InitiateCharging {
        doc "Initiate the battery charging process.";
    }

    action def MonitorCharging {
        doc "Monitor the charging process until complete.";
        out chargingComplete : Boolean;
    }

    action def PrepareForOperation {
        doc "Prepare the mower for resuming operation after charging.";
        out ready : Boolean;
    }

    // ===== Composite Action Definitions =====
    action def ScanForObstacles {
        doc "Scan for obstacles using ultrasonic and bump sensors.";
        in ultrasonicFront : ObstacleDetection;
        in ultrasonicRear : ObstacleDetection;
        in bumpFront : BumpEvent;
        in bumpRear : BumpEvent;
        out obstacleDetected : Boolean;
        out obstacleDistance : Distance;
        out obstacleType : ObstacleType;
    }

    action def CheckBoundary {
        doc "Check position relative to boundary wire.";
        in boundaryData : BoundarySignal;
        out boundaryDetected : Boolean;
    }

    action def CheckBatteryLevel {
        doc "Check battery charge level against threshold.";
        in batteryStatus : BatteryStatus;
        in threshold : Percent;
        out batteryLevel : Percent;
        out batteryLow : Boolean;
    }

    action def ExecuteMowingPass {
        doc "Execute a forward mowing pass at target speed.";
        in targetSpeed : Speed;
        in bladeHeight : GrassHeight;
        out driveCmd : DriveCommand;
        out bladeCmd : BladeCommand;
    }

    action def PerformObstacleAvoidance {
        doc "Stop, turn, and find a clear path around obstacle.";
        in obstacleDistance : Distance;
        in obstacleType : ObstacleType;
        out turnDirection : TurnDirection;
        out turnAngle : Angle;
        out driveCmd : DriveCommand;
        out clearPathFound : Boolean;
    }

    action def PerformBoundaryTurn {
        doc "Turn around at boundary to continue mowing within area.";
        out turnDirection : TurnDirection;
        out turnAngle : Angle;
        out driveCmd : DriveCommand;
        out turnComplete : Boolean;
    }

    action def NavigateToDock {
        doc "Navigate mower back to charging dock using beacon signal.";
        in beaconSignal : DockingBeaconSignal;
        out driveCmd : DriveCommand;
        out dockReached : Boolean;
    }

    action def ExecuteMowingSequence {
        doc "Continuous mowing sequence with obstacle, boundary, and battery checking.";

        in targetSpeed : Speed = 0.3;
        in targetGrassHeight : GrassHeight = 40;
        in lowBatteryThreshold : Percent = 15;
        in ultrasonicFrontData : ObstacleDetection;
        in ultrasonicRearData : ObstacleDetection;
        in bumpFrontData : BumpEvent;
        in bumpRearData : BumpEvent;
        in boundaryData : BoundarySignal;
        in batteryData : BatteryStatus;
        in beaconData : DockingBeaconSignal;
        out driveCmd : DriveCommand;
        out bladeCmd : BladeCommand;
        out batteryLow : Boolean;
        out dockReached : Boolean;

        action scanObstacles : ScanForObstacles {
            in ultrasonicFront = ultrasonicFrontData;
            in ultrasonicRear = ultrasonicRearData;
            in bumpFront = bumpFrontData;
            in bumpRear = bumpRearData;
        }

        action checkBoundary : CheckBoundary {
            in boundaryData = boundaryData;
        }

        action checkBattery : CheckBatteryLevel {
            in batteryStatus = batteryData;
            in threshold = lowBatteryThreshold;
        }

        action mowForward : ExecuteMowingPass {
            in targetSpeed = targetSpeed;
            in bladeHeight = targetGrassHeight;
        }

        action avoidObstacle : PerformObstacleAvoidance {
            in obstacleDistance = scanObstacles.obstacleDistance;
            in obstacleType = scanObstacles.obstacleType;
        }

        action turnAtBoundary : PerformBoundaryTurn;

        action navigateDock : NavigateToDock {
            in beaconSignal = beaconData;
        }

        first scanObstacles;
        succession scanObstacles then checkBoundary;
        succession checkBoundary then checkBattery;

        succession checkBattery then avoidObstacle if scanObstacles.obstacleDetected;
        succession checkBattery then turnAtBoundary if checkBoundary.boundaryDetected;
        succession checkBattery then navigateDock if checkBattery.batteryLow;
        succession checkBattery then mowForward if !scanObstacles.obstacleDetected and !checkBoundary.boundaryDetected and !checkBattery.batteryLow;

        succession avoidObstacle then scanObstacles;
        succession turnAtBoundary then scanObstacles;
        succession mowForward then scanObstacles;

        flow mowForward.driveCmd to driveCmd;
        flow mowForward.bladeCmd to bladeCmd;
        flow avoidObstacle.driveCmd to driveCmd;
        flow turnAtBoundary.driveCmd to driveCmd;
        flow navigateDock.driveCmd to driveCmd;
        flow checkBattery.batteryLow to batteryLow;
        flow navigateDock.dockReached to dockReached;
    }

    // ===== Requirement Definitions =====
    requirement def SystemRequirement {
        doc "The autonomous robotic lawn mower system shall automatically maintain a lawn without human intervention.";
        attribute maxLawnArea : Area = 2000;
        attribute maxAutonomyTime : TimeValue = 7200;
    }

    requirement def AutonomousMowingReq {
        doc "The mower shall execute an autonomous mowing sequence covering the entire lawn area.";
        attribute coverageTarget : Percent = 95;
        attribute maxGrassHeight : GrassHeight = 60;
        attribute targetGrassHeight : GrassHeight = 40;
    }

    requirement def ObstacleAvoidanceReq {
        doc "The mower shall detect obstacles using ultrasonic sensors and perform avoidance maneuvers.";
        attribute detectionRange : Distance = 0.5;
        attribute minStopDistance : Distance = 0.1;
    }

    requirement def BoundaryDetectionReq {
        doc "The mower shall detect the perimeter boundary wire signal and turn around to stay within the designated area.";
        attribute signalFrequency : Frequency = 10000;
    }

    requirement def BumpSensorReq {
        doc "The mower shall have contact-based bump sensors as a backup obstacle detection mechanism.";
    }

    requirement def GrassHeightSensingReq {
        doc "The mower shall measure grass height to ensure uniform cutting.";
        attribute heightAccuracy : GrassHeight = 2;
    }

    requirement def BatteryMonitoringReq {
        doc "The mower shall monitor its battery level and return to the charging dock when charge drops below threshold.";
        attribute lowBatteryThreshold : Percent = 15;
        attribute fullChargeThreshold : Percent = 100;
    }

    requirement def AutoDockingReq {
        doc "The mower shall autonomously navigate to and dock with the charging station.";
        attribute maxDockingTime : TimeValue = 300;
    }

    requirement def ChargingCycleReq {
        doc "The charging dock shall recharge the mower battery and the mower shall resume mowing when fully charged.";
        attribute chargeTime : TimeValue = 3600;
    }

    requirement def DriveSystemReq {
        doc "The drive system shall use two independently controlled wheels for forward movement and precise turns.";
        attribute maxSpeed : Speed = 0.5;
        attribute minTurnRadius : Distance = 0.0;
    }

    requirement def CuttingDeckReq {
        doc "The cutting deck shall contain rotating blades set to a specific height for uniform grass length.";
        attribute bladeSpeed : RotationalSpeed = 3000;
        attribute heightRange : GrassHeight = 20;
    }

    // ===== State Machine Definition =====
    state def MowerStateMachine {
        doc "State machine governing mower operational modes: mowing, navigating, docking, and obstacle avoidance.";

        initial -> Off;

        state Off {
            doc "Mower is powered off.";
            entry action PowerOffSystems();
        }

        state Idle {
            doc "Mower is powered on and waiting for commands.";
            entry action InitializeSystems();
            do action WaitForCommand();
        }

        state Mowing {
            doc "Mower is actively cutting grass.";
            entry action StartBlades();
            do action ExecuteMowingSequence();
            exit action StopBlades();
        }

        state ObstacleAvoidance {
            doc "Mower detected an obstacle and is performing avoidance maneuver.";
            entry action StopMower();
            do action PerformObstacleAvoidance();
        }

        state BoundaryTurn {
            doc "Mower reached boundary wire and is turning around.";
            entry action StopMower();
            do action PerformBoundaryTurn();
        }

        state NavigatingToDock {
            doc "Mower is navigating back to charging dock due to low battery.";
            entry action StopBlades();
            do action NavigateToDock();
        }

        state Docking {
            doc "Mower is aligning and connecting with the charging dock.";
            do action PerformDocking();
        }

        state Charging {
            doc "Mower is charging at the dock.";
            entry action InitiateCharging();
            do action MonitorCharging();
            exit action PrepareForOperation();
        }

        transition from Off to Idle when powerOn;
        transition from Idle to Mowing when startMowingCommand;
        transition from Idle to Off when powerOff;

        transition from Mowing to ObstacleAvoidance when obstacleDetected;
        transition from Mowing to BoundaryTurn when boundaryDetected;
        transition from Mowing to NavigatingToDock when batteryLevel <= lowBatteryThreshold;
        transition from Mowing to Idle when mowingComplete;

        transition from ObstacleAvoidance to Mowing when clearPathFound;

        transition from BoundaryTurn to Mowing when turnComplete;

        transition from NavigatingToDock to Docking when dockReached;
        transition from NavigatingToDock to ObstacleAvoidance when obstacleDetected;

        transition from Docking to Charging when docked;
        transition from Docking to NavigatingToDock when dockingTimeout;

        transition from Charging to Idle when batteryLevel >= fullChargeThreshold;
    }

    // ===== Leaf Part Definitions =====
    part def Wheel {
        doc "Independent drive wheel for the mower.";
        attribute diameter : Distance = 0.2;
        attribute maxSpeed : AngularVelocity = 5.0;
        attribute currentSpeed : AngularVelocity = 0.0;
    }

    part def Blade {
        doc "Rotating cutting blade for grass cutting.";
        attribute length : Distance = 0.25;
        attribute maxRotationalSpeed : RotationalSpeed = 3500;
        attribute currentSpeed : RotationalSpeed = 0;
    }

    part def UltrasonicSensor {
        doc "Ultrasonic sensor for obstacle detection at a distance.";
        attribute maxRange : Distance = 2.0;
        attribute detectionRange : Distance = 0.5;
        attribute fieldOfView : Angle = 60;
        attribute detected : Boolean = false;
        attribute measuredDistance : Distance = 0.0;

        port powerIn : PowerInPort;
        port dataOut : ObstacleOutPort;

        exhibit action scan {
            out obstacleData : ObstacleDetection;
            first emit ultrasonicPulse;
            then wait for echo;
            then calculate distance;
            then if measuredDistance <= detectionRange then
                set detected := true;
            else
                set detected := false;
            then send obstacleData via dataOut;
        }
    }

    part def BoundaryWireSensor {
        doc "Sensor to detect perimeter boundary wire signal.";
        attribute detectionFrequency : Frequency = 10000;
        attribute detected : Boolean = false;
        attribute signalStrength : SignalStrength = 0;
        attribute detectionThreshold : SignalStrength = 30;

        port powerIn : PowerInPort;
        port dataOut : BoundaryOutPort;
        port externalIn : BoundaryInPort;

        exhibit action detectBoundary {
            out boundaryData : BoundarySignal;
            first listen for signal at detectionFrequency;
            then if signalStrength > detectionThreshold then
                set detected := true;
            else
                set detected := false;
            then send boundaryData via dataOut;
        }
    }

    part def BumpSensor {
        doc "Contact-based bump sensor for backup obstacle detection.";
        attribute triggered : Boolean = false;
        attribute sensitivity : Real = 0.5;

        port powerIn : PowerInPort;
        port dataOut : BumpOutPort;

        exhibit action monitorContact {
            out bumpEvent : BumpEvent;
            first detect physical contact;
            then if contactDetected then
                set triggered := true;
            else
                set triggered := false;
            then send bumpEvent via dataOut;
        }
    }

    part def GrassHeightSensor {
        doc "Sensor to measure grass height for uniform cutting.";
        attribute measuredHeight : GrassHeight = 0;
        attribute range : GrassHeight = 100;
        attribute accuracy : GrassHeight = 2;

        port powerIn : PowerInPort;
        port dataOut : GrassHeightOutPort;

        exhibit action measureGrassHeight {
            out heightReading : GrassHeightReading;
            first measure grass height;
            then set measuredHeight := reading;
            then send heightReading via dataOut;
        }
    }

    part def PerimeterWire {
        doc "Perimeter boundary wire emitting signal for boundary detection.";
        attribute signalFrequency : Frequency = 10000;
        attribute signalStrength : SignalStrength = 80;
        attribute perimeterLength : Distance = 200;
        attribute active : Boolean = true;

        port signalOut : BoundaryOutPort;

        exhibit action emitSignal {
            first generate electromagnetic signal at signalFrequency;
            then broadcast signal via signalOut;
        }
    }

    part def DockPowerSupply {
        doc "Power supply for the charging dock converting mains to DC.";
        attribute inputVoltage : Voltage = 230;
        attribute outputVoltage : Voltage = 24;
        attribute outputCurrent : Current = 2.0;
        attribute maxPower : Power = 48;

        port powerOut : PowerOutPort;
    }

    part def DockingBeacon {
        doc "Docking beacon emitter to guide mower to dock.";
        attribute frequency : Frequency = 433;
        attribute active : Boolean = true;
        attribute range : Distance = 10;

        port powerIn : PowerInPort;
        port signalOut : BeaconOutPort;

        exhibit action emitBeacon {
            first generate beacon signal at frequency;
            then broadcast signal via signalOut;
        }
    }

    part def DockChargingContacts {
        doc "Charging contacts on the dock for mower connection.";
        attribute contactVoltage : Voltage = 24;
        attribute contactCurrent : Current = 2.0;

        port powerIn : PowerInPort;
        port contactOut : DockingPort;
    }

    // ===== Composite Part Definitions =====
    part def BatterySystem {
        doc "Rechargeable battery system powering the mower drive, cutting deck, sensors, and controller.";
        attribute capacity : Energy = 100;
        attribute currentCharge : Percent = 100;
        attribute nominalVoltage : Voltage = 24;
        attribute chargingCurrent : Current = 2.0;
        attribute lowThreshold : Percent = 15;
        attribute fullChargeThreshold : Percent = 100;
        attribute status : ChargingStatus = ChargingStatus::notCharging;

        port powerOut : PowerOutPort;
        port statusOut : BatteryStatusOutPort;
        port chargeIn : DockingPort;

        exhibit state batteryState {
            initial -> Discharged;

            state Discharged {
                entry action setChargeLevel(currentCharge := 0);
            }

            state Charging {
                entry action startCharging();
                do action monitorCharge();
                exit action stopCharging();
            }

            state Charged {
                entry action setChargeLevel(currentCharge := 100);
            }

            state Discharging {
                do action monitorDischarge();
            }

            transition from Discharged to Charging when chargeIn.charge.current > 0;
            transition from Charging to Charged when currentCharge >= fullChargeThreshold;
            transition from Charged to Discharging when powerOut.power.current > 0;
            transition from Discharging to Discharged when currentCharge <= 0;
            transition from Discharging to Charging when chargeIn.charge.current > 0;
        }
    }

    part def DriveSystem {
        doc "Drive system with two independently controlled wheels for forward movement and precise turns.";
        attribute maxSpeed : Speed = 0.5;
        attribute leftWheelSpeed : AngularVelocity = 0;
        attribute rightWheelSpeed : AngularVelocity = 0;

        port powerIn : PowerInPort;
        port commandIn : DriveCmdInPort;

        part leftWheel : Wheel {
            attribute diameter : Distance = 0.2;
            attribute maxSpeed : AngularVelocity = 5.0;
        }

        part rightWheel : Wheel {
            attribute diameter : Distance = 0.2;
            attribute maxSpeed : AngularVelocity = 5.0;
        }

        exhibit action driveControl {
            in cmd : DriveCommand via commandIn;
            in power : PowerFlow via powerIn;
            out leftWheelCommand : AngularVelocity;
            out rightWheelCommand : AngularVelocity;

            first receive cmd;
            then set leftWheelSpeed := cmd.leftWheelSpeed;
            then set rightWheelSpeed := cmd.rightWheelSpeed;
            then send leftWheelCommand to leftWheel;
            then send rightWheelCommand to rightWheel;
        }
    }

    part def CuttingDeck {
        doc "Cutting deck with rotating blades at adjustable height for uniform grass length.";
        attribute bladeHeight : GrassHeight = 40;
        attribute bladeSpeed : RotationalSpeed = 3000;
        attribute bladeCount : Integer = 1;

        port powerIn : PowerInPort;
        port commandIn : BladeCmdInPort;

        part blade : Blade {
            attribute length : Distance = 0.25;
            attribute maxRotationalSpeed : RotationalSpeed = 3500;
        }

        exhibit action cuttingControl {
            in cmd : BladeCommand via commandIn;
            in power : PowerFlow via powerIn;

            first receive cmd;
            then if cmd.status == BladeStatus::spinning then
                set bladeSpeed := 3000;
            else
                set bladeSpeed := 0;
            then set bladeHeight := cmd.heightSetting;
        }
    }

    part def SensorArray {
        doc "Comprehensive sensor array for autonomous navigation and safety.";

        port powerIn : PowerInPort;

        part frontUltrasonic : UltrasonicSensor {
            attribute maxRange : Distance = 2.0;
            attribute detectionRange : Distance = 0.5;
            attribute fieldOfView : Angle = 60;
        }

        part rearUltrasonic : UltrasonicSensor {
            attribute maxRange : Distance = 2.0;
            attribute detectionRange : Distance = 0.5;
            attribute fieldOfView : Angle = 60;
        }

        part boundarySensor : BoundaryWireSensor {
            attribute detectionFrequency : Frequency = 10000;
        }

        part frontBumpSensor : BumpSensor {
            attribute sensitivity : Real = 0.5;
        }

        part rearBumpSensor : BumpSensor {
            attribute sensitivity : Real = 0.5;
        }

        part grassHeightSensor : GrassHeightSensor {
            attribute range : GrassHeight = 100;
            attribute accuracy : GrassHeight = 2;
        }

        connection connect powerIn to frontUltrasonic.powerIn;
        connection connect powerIn to rearUltrasonic.powerIn;
        connection connect powerIn to boundarySensor.powerIn;
        connection connect powerIn to frontBumpSensor.powerIn;
        connection connect powerIn to rearBumpSensor.powerIn;
        connection connect powerIn to grassHeightSensor.powerIn;
    }

    part def NavigationControlUnit {
        doc "Navigation and control unit managing operational modes: mowing, navigating, docking, and obstacle avoidance.";
        attribute lowBatteryThreshold : Percent = 15;
        attribute fullChargeThreshold : Percent = 100;
        attribute targetGrassHeight : GrassHeight = 40;
        attribute currentMode : OperationalMode = OperationalMode::off;
        attribute currentBatteryLevel : Percent = 100;
        attribute obstacleDetected : Boolean = false;
        attribute boundaryDetected : Boolean = false;
        attribute clearPathFound : Boolean = false;
        attribute turnComplete : Boolean = false;
        attribute dockReached : Boolean = false;
        attribute docked : Boolean = false;
        attribute dockingTimeout : Boolean = false;
        attribute mowingComplete : Boolean = false;
        attribute powerOn : Boolean = false;
        attribute powerOff : Boolean = false;
        attribute startMowingCommand : Boolean = false;

        port powerIn : PowerInPort;
        port ultrasonicFrontIn : ObstacleInPort;
        port ultrasonicRearIn : ObstacleInPort;
        port boundaryDataIn : BoundaryInPort;
        port bumpFrontIn : BumpInPort;
        port bumpRearIn : BumpInPort;
        port grassHeightIn : GrassHeightInPort;
        port beaconIn : BeaconInPort;
        port batteryStatusIn : BatteryStatusInPort;
        port driveCommandOut : DriveCmdOutPort;
        port bladeCommandOut : BladeCmdOutPort;

        exhibit state mowerStateMachine : MowerStateMachine;
    }

    part def ChargingDock {
        doc "Dedicated charging dock station for the robotic mower.";
        attribute outputVoltage : Voltage = 24;
        attribute outputCurrent : Current = 2.0;
        attribute beaconFrequency : Frequency = 433;

        port beaconOut : BeaconOutPort;
        port dockingContact : DockingPort;

        part powerSupply : DockPowerSupply {
            attribute inputVoltage : Voltage = 230;
            attribute outputVoltage : Voltage = 24;
            attribute outputCurrent : Current = 2.0;
            attribute maxPower : Power = 48;
        }

        part beaconEmitter : DockingBeacon {
            attribute frequency : Frequency = 433;
            attribute range : Distance = 10;
        }

        part chargingContacts : DockChargingContacts {
            attribute contactVoltage : Voltage = 24;
            attribute contactCurrent : Current = 2.0;
        }

        connection connect powerSupply.powerOut to chargingContacts.powerIn;
        connection connect powerSupply.powerOut to beaconEmitter.powerIn;
        connection connect beaconEmitter.signalOut to beaconOut;
        connection connect chargingContacts.contactOut to dockingContact;
    }

    part def RoboticMower {
        doc "Self-propelled autonomous robotic lawn mower with drive system, cutting deck, sensor array, and navigation controller.";
        attribute mass : Mass = 12;
        attribute maxSpeed : Speed = 0.5;
        attribute currentMode : OperationalMode = OperationalMode::off;

        port beaconIn : BeaconInPort;
        port dockingContact : DockingPort;
        port boundarySensorIn : BoundaryInPort;

        part batterySystem : BatterySystem {
            attribute capacity : Energy = 100;
            attribute currentCharge : Percent = 100;
            attribute nominalVoltage : Voltage = 24;
        }

        part driveSystem : DriveSystem {
            attribute maxSpeed : Speed = 0.5;

            part leftWheel : Wheel {
                attribute diameter : Distance = 0.2;
            }

            part rightWheel : Wheel {
                attribute diameter : Distance = 0.2;
            }
        }

        part cuttingDeck : CuttingDeck {
            attribute bladeHeight : GrassHeight = 40;
            attribute bladeSpeed : RotationalSpeed = 3000;

            part blade : Blade {
                attribute length : Distance = 0.25;
            }
        }

        part sensorArray : SensorArray {
            part frontUltrasonic : UltrasonicSensor {
                attribute detectionRange : Distance = 0.5;
            }

            part rearUltrasonic : UltrasonicSensor {
                attribute detectionRange : Distance = 0.5;
            }

            part boundarySensor : BoundaryWireSensor {
                attribute detectionFrequency : Frequency = 10000;
            }

            part frontBumpSensor : BumpSensor;
            part rearBumpSensor : BumpSensor;
            part grassHeightSensor : GrassHeightSensor;
        }

        part controlUnit : NavigationControlUnit {
            attribute lowBatteryThreshold : Percent = 15;
            attribute targetGrassHeight : GrassHeight = 40;
        }

        // Power distribution connections
        connection powerToDrive connect batterySystem.powerOut to driveSystem.powerIn;
        connection powerToCuttingDeck connect batterySystem.powerOut to cuttingDeck.powerIn;
        connection powerToSensors connect batterySystem.powerOut to sensorArray.powerIn;
        connection powerToController connect batterySystem.powerOut to controlUnit.powerIn;

        // Sensor data to controller connections
        connection frontUltrasonicData connect sensorArray.frontUltrasonic.dataOut to controlUnit.ultrasonicFrontIn;
        connection rearUltrasonicData connect sensorArray.rearUltrasonic.dataOut to controlUnit.ultrasonicRearIn;
        connection boundarySensorData connect sensorArray.boundarySensor.dataOut to controlUnit.boundaryDataIn;
        connection frontBumpData connect sensorArray.frontBumpSensor.dataOut to controlUnit.bumpFrontIn;
        connection rearBumpData connect sensorArray.rearBumpSensor.dataOut to controlUnit.bumpRearIn;
        connection grassHeightData connect sensorArray.grassHeightSensor.dataOut to controlUnit.grassHeightIn;

        // Controller command connections
        connection driveCommand connect controlUnit.driveCommandOut to driveSystem.commandIn;
        connection bladeCommand connect controlUnit.bladeCommandOut to cuttingDeck.commandIn;

        // Battery status to controller
        connection batteryStatus connect batterySystem.statusOut to controlUnit.batteryStatusIn;

        // External port delegations
        connection beaconToController connect beaconIn to controlUnit.beaconIn;
        connection boundaryToSensor connect boundarySensorIn to sensorArray.boundarySensor.externalIn;
        connection dockingToBattery connect dockingContact to batterySystem.chargeIn;

        satisfy AutonomousMowingReq;
        satisfy ObstacleAvoidanceReq;
        satisfy BoundaryDetectionReq;
        satisfy BumpSensorReq;
        satisfy GrassHeightSensingReq;
        satisfy BatteryMonitoringReq;
        satisfy AutoDockingReq;
        satisfy DriveSystemReq;
        satisfy CuttingDeckReq;
    }

    // ===== System Part Definition =====
    part def RoboticMowerSystem {
        doc "Complete autonomous robotic lawn mower system including mower, charging dock, and perimeter wire.";
        attribute lawnArea : Area = 1000;
        attribute systemActive : Boolean = true;

        part mower : RoboticMower {
            attribute mass : Mass = 12;
        }

        part dock : ChargingDock {
            attribute outputVoltage : Voltage = 24;
            attribute outputCurrent : Current = 2.0;
        }

        part perimeterWire : PerimeterWire {
            attribute signalFrequency : Frequency = 10000;
            attribute signalStrength : SignalStrength = 80;
            attribute perimeterLength : Distance = 200;
        }

        // System-level connections
        connection dockBeaconSignal connect dock.beaconOut to mower.beaconIn;
        connection dockingConnection connect mower.dockingContact to dock.dockingContact;
        connection perimeterSignal connect perimeterWire.signalOut to mower.boundarySensorIn;

        satisfy SystemRequirement;
        satisfy ChargingCycleReq;
        satisfy BoundaryDetectionReq;
    }
}
