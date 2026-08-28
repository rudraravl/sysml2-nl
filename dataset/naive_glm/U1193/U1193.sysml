package AutonomousVacuumSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====

    value type Power implements Real {
        unit 'W';
    }

    value type Voltage implements Real {
        unit 'V';
    }

    value type Current implements Real {
        unit 'A';
    }

    value type Energy implements Real {
        unit 'Wh';
    }

    value type BatteryLevel implements Real {
        unit '%';
    }

    value type Distance implements Real {
        unit 'm';
    }

    value type AngularVelocity implements Real {
        unit 'rad/s';
    }

    value type LinearVelocity implements Real {
        unit 'm/s';
    }

    value type RotationalSpeed implements Real {
        unit 'rpm';
    }

    value type Mass implements Real {
        unit 'g';
    }

    value type Area implements Real {
        unit 'm^2';
    }

    value type Duration implements Real {
        unit 's';
    }

    value type Pressure implements Real {
        unit 'Pa';
    }

    value type Temperature implements Real {
        unit 'degC';
    }

    // ===== Enumerations =====

    enum CleaningMode { idle, active, spot, returning, charging }

    enum ObstacleType { none, near, contact, cliff, dirt }

    enum DockingStatus { undocked, seeking, docked }

    enum BrushDirection { clockwise, counterClockwise }

    // ===== Item Definitions =====

    item def Debris {
        attribute particleSize : Mass;
        attribute composition : String;
    }

    item def Dust :> Debris {
        attribute density : Real;
    }

    item def AirFlow {
        attribute flowRate : Real;
        attribute pressure : Pressure;
    }

    item def SensorReading {
        attribute obstacleDetected : Boolean;
        attribute distance : Distance;
        attribute obstacleType : ObstacleType;
    }

    item def NavigationCommand {
        attribute targetLinearVelocity : LinearVelocity;
        attribute targetAngularVelocity : AngularVelocity;
        attribute mode : CleaningMode;
    }

    item def PowerCommand {
        attribute fanPower : Power;
        attribute mainBrushEnabled : Boolean;
        attribute sideBrushEnabled : Boolean;
    }

    item def BatteryStatus {
        attribute chargeLevel : BatteryLevel;
        attribute voltage : Voltage;
        attribute temperature : Temperature;
        attribute estimatedTimeRemaining : Duration;
    }

    item def DockSignal {
        attribute signalStrength : Real;
        attribute dockPosition : Distance;
    }

    // ===== Port Definitions =====

    port def PowerPort {
        attribute voltage : Voltage;
        attribute current : Current;
        out item power : Power;
    }

    port def SensorDataPort {
        out item reading : SensorReading;
    }

    port def MotorCommandPort {
        in item command : NavigationCommand;
    }

    port def CleaningCommandPort {
        in item command : PowerCommand;
    }

    port def BatteryStatusPort {
        out item status : BatteryStatus;
    }

    port def DockSignalPort {
        out item signal : DockSignal;
    }

    port def DockingPort {
        attribute docked : Boolean;
        in item power : Power;
    }

    port def DebrisFlowPort {
        in item debris : Debris;
        out item filteredAir : AirFlow;
    }

    // ===== Interfaces =====

    interface def PowerInterface {
        end supplier : PowerPort;
        end consumer : PowerPort;
        flow power from supplier.power to consumer.power;
    }

    interface def SensorDataInterface {
        end sensor : SensorDataPort;
        end controller :>> SensorDataPort;
        flow reading from sensor.reading to controller.reading;
    }

    interface def MotorCommandInterface {
        end controller : MotorCommandPort;
        end motor :>> MotorCommandPort;
        flow command from controller.command to motor.command;
    }

    interface def DockingInterface {
        end dock : DockingPort;
        end robot :>> DockingPort;
        flow power from dock.power to robot.power;
    }

    // ===== Requirements =====

    requirement def CleaningRequirement {
        doc /* The system shall clean floor surfaces autonomously. */
        attribute coverageArea : Area = 120 [m^2];
        subject vacuum : RobotVacuum;
        require vacuum.cleaningCoverage >= coverageArea;
    }

    requirement def NavigationRequirement {
        doc /* The robot shall navigate autonomously avoiding obstacles. */
        subject vacuum : RobotVacuum;
        require vacuum.navigationController.obstacleAvoidance == true;
    }

    requirement def BatteryRequirement {
        doc /* The robot shall autonomously recharge when battery is low. */
        attribute lowThreshold : BatteryLevel = 20 [%];
        attribute fullThreshold : BatteryLevel = 100 [%];
        subject vacuum : RobotVacuum;
        require vacuum.battery.chargeLevel >= lowThreshold or vacuum.state == ChargingMode::returning;
    }

    requirement def CliffSafetyRequirement {
        doc /* The robot shall not fall down stairs or ledges. */
        subject vacuum : RobotVacuum;
        require vacuum.cliffSensor.active == true;
    }

    requirement def SpotCleaningRequirement {
        doc /* The robot shall perform spot cleaning when dirt is detected. */
        subject vacuum : RobotVacuum;
        require vacuum.dirtSensor.detectionEnabled == true;
    }

    requirement def DockingRequirement {
        doc /* The charging dock shall provide reliable docking and charging. */
        attribute chargingPower : Power = 30 [W];
        subject dock : ChargingDock;
        require dock.chargingOutput >= chargingPower;
    }

    // ===== Component Part Definitions =====

    part def SideBrush {
        attribute direction : BrushDirection;
        attribute speed : RotationalSpeed = 150 [rpm];
        attribute powerConsumption : Power = 1.5 [W];
        port commandIn : CleaningCommandPort;
        perform action rotate {
            in cmd : PowerCommand = commandIn.command;
            if cmd.sideBrushEnabled then {
                // brush rotates to sweep debris inward
            }
        }
    }

    part def MainBrush {
        attribute speed : RotationalSpeed = 800 [rpm];
        attribute powerConsumption : Power = 5 [W];
        attribute brushLength : Distance = 0.2 [m];
        port commandIn : CleaningCommandPort;
        perform action agitate {
            in cmd : PowerCommand = commandIn.command;
            if cmd.mainBrushEnabled then {
                // main brush agitates floor surface
            }
        }
    }

    part def SuctionFan {
        attribute maxPower : Power = 40 [W];
        attribute currentPower : Power;
        attribute suctionPressure : Pressure = 2000 [Pa];
        port commandIn : CleaningCommandPort;
        port debrisOut : DebrisFlowPort;
        perform action generateSuction {
            in cmd : PowerCommand = commandIn.command;
            // fan pulls dislodged debris into dust container
            currentPower = cmd.fanPower;
        }
    }

    part def DustContainer {
        attribute capacity : Mass = 500 [g];
        attribute currentFill : Mass = 0 [g];
        attribute filterEfficiency : Real = 0.99;
        port debrisIn : DebrisFlowPort;
        port filteredAirOut : DebrisFlowPort;
        perform action collectDebris {
            in d : Debris = debrisIn.debris;
            currentFill = currentFill + d.particleSize;
        }
    }

    part def DriveWheel {
        attribute diameter : Distance = 0.06 [m];
        attribute maxSpeed : LinearVelocity = 0.5 [m/s];
        attribute powerConsumption : Power = 3 [W];
        port commandIn : MotorCommandPort;
        perform action drive {
            in cmd : NavigationCommand = commandIn.command;
            // wheel moves based on navigation command
        }
    }

    part def DriveWheelAssembly {
        part leftWheel : DriveWheel {
            attribute side = "left";
        }
        part rightWheel : DriveWheel {
            attribute side = "right";
        }
    }

    part def LithiumBattery {
        attribute capacity : Energy = 30 [Wh];
        attribute nominalVoltage : Voltage = 14.4 [V];
        attribute chargeLevel : BatteryLevel = 100 [%];
        attribute lowThreshold : BatteryLevel = 20 [%];
        attribute fullThreshold : BatteryLevel = 100 [%];
        attribute chargingRate : Power = 30 [W];
        port powerOut : PowerPort;
        port statusOut : BatteryStatusPort;
        port chargingIn : PowerPort;
        perform action discharge {
            out p : Power = powerOut.power;
            // battery supplies power to robot components
        }
        perform action charge {
            in p : Power = chargingIn.power;
            // battery charges from dock
            if chargeLevel < fullThreshold then {
                chargeLevel = chargeLevel + 1 [%];
            }
        }
        perform action reportStatus {
            out s : BatteryStatus = statusOut.status {
                chargeLevel = chargeLevel;
                voltage = nominalVoltage;
            }
        }
    }

    part def IRSensor {
        attribute detectionRange : Distance = 0.3 [m];
        attribute active : Boolean = true;
        attribute position : String;
        port dataOut : SensorDataPort;
        perform action detect {
            out r : SensorReading = dataOut.reading {
                distance = detectionRange;
                obstacleType = ObstacleType::near;
            }
        }
    }

    part def BumperSensor {
        attribute active : Boolean = true;
        attribute contactForce : Real;
        port dataOut : SensorDataPort;
        perform action detectContact {
            out r : SensorReading = dataOut.reading {
                distance = 0 [m];
                obstacleType = ObstacleType::contact;
            }
        }
    }

    part def CliffSensor {
        attribute active : Boolean = true;
        attribute detectionRange : Distance = 0.05 [m];
        port dataOut : SensorDataPort;
        perform action detectCliff {
            out r : SensorReading = dataOut.reading {
                obstacleType = ObstacleType::cliff;
            }
        }
    }

    part def DirtSensor {
        attribute detectionEnabled : Boolean = true;
        attribute sensitivity : Real = 0.8;
        attribute dirtThreshold : Mass = 5 [g];
        port dataOut : SensorDataPort;
        perform action detectDirt {
            out r : SensorReading = dataOut.reading {
                obstacleType = ObstacleType::dirt;
            }
        }
    }

    part def NavigationController {
        attribute obstacleAvoidance : Boolean = true;
        attribute pathPlanned : Boolean = false;
        attribute currentMode : CleaningMode = CleaningMode::idle;
        port sensorDataIn : SensorDataPort;
        port motorCommandOut : MotorCommandPort;
        port cleaningCommandOut : CleaningCommandPort;
        port batteryStatusIn : BatteryStatusPort;
        port dockSignalIn : DockSignalPort;
        perform action processSensorData {
            in r : SensorReading = sensorDataIn.reading;
            // process all sensor readings and determine navigation
        }
        perform action planPath {
            // create systematic cleaning path
            pathPlanned = true;
        }
        perform action generateCommands {
            out navCmd : NavigationCommand = motorCommandOut.command {
                mode = currentMode;
            };
            out cleanCmd : PowerCommand = cleaningCommandOut.command {
                fanPower = 30 [W];
                mainBrushEnabled = true;
                sideBrushEnabled = true;
            };
        }
        state navigationStateMachine {
            entry;
            then idle;
            state idle {
                entry;
                // waiting for activation
            }
            transition from idle to active
                when sensorDataIn.reading.obstacleType != ObstacleType::none;
            state active {
                entry;
                // systematic room navigation
            }
            transition from active to spot
                when sensorDataIn.reading.obstacleType == ObstacleType::dirt;
            state spot {
                entry;
                // intensive spot cleaning spiral pattern
            }
            transition from spot to active
                when sensorDataIn.reading.obstacleType != ObstacleType::dirt;
            transition from active to returning
                when batteryStatusIn.status.chargeLevel <= 20 [%];
            transition from spot to returning
                when batteryStatusIn.status.chargeLevel <= 20 [%];
            state returning {
                entry;
                // navigate back to charging dock using dock signal
            }
            transition from returning to charging
                when dockSignalIn.signal.signalStrength > 0.9;
            state charging {
                entry;
                // docked and charging
            }
            transition from charging to idle
                when batteryStatusIn.status.chargeLevel >= 100 [%];
        }
    }

    part def SensorSuite {
        part frontIR : IRSensor {
            attribute position = "front";
        }
        part leftIR : IRSensor {
            attribute position = "left";
        }
        part rightIR : IRSensor {
            attribute position = "right";
        }
        part bumper : BumperSensor;
        part leftCliff : CliffSensor {
            attribute position = "left";
        }
        part rightCliff : CliffSensor {
            attribute position = "right";
        }
        part frontCliff : CliffSensor {
            attribute position = "front";
        }
        part dirt : DirtSensor;
    }

    part def CleaningAssembly {
        part leftSideBrush : SideBrush {
            attribute direction = BrushDirection::clockwise;
        }
        part rightSideBrush : SideBrush {
            attribute direction = BrushDirection::counterClockwise;
        }
        part mainBrush : MainBrush;
        part suctionFan : SuctionFan;
        part dustContainer : DustContainer;
        connect suctionFan.debrisOut to dustContainer.debrisIn;
        connect dustContainer.filteredAirOut to suctionFan.debrisOut;
    }

    part def ChargingDock {
        attribute outputVoltage : Voltage = 14.4 [V];
        attribute chargingOutput : Power = 30 [W];
        attribute dockSignalStrength : Real = 1.0;
        port powerOut : PowerPort;
        port dockSignalOut : DockSignalPort;
        port dockingPort : DockingPort;
        perform action providePower {
            out p : Power = powerOut.power {
                // dock provides charging power
            };
        }
        perform action emitDockSignal {
            out s : DockSignal = dockSignalOut.signal {
                signalStrength = dockSignalStrength;
            };
        }
    }

    // ===== Main Robot Vacuum =====

    part def RobotVacuum {
        attribute cleaningCoverage : Area = 150 [m^2];
        attribute state : CleaningMode = CleaningMode::idle;
        attribute dockingStatus : DockingStatus = DockingStatus::undocked;

        port dockingPort : DockingPort;
        port dockSignalPort : DockSignalPort;

        part battery : LithiumBattery;
        part driveWheels : DriveWheelAssembly;
        part cleaningAssembly : CleaningAssembly;
        part sensorSuite : SensorSuite;
        part navigationController : NavigationController;

        // Power distribution
        connect battery.powerOut to navigationController.batteryStatusIn;
        connect battery.powerOut to driveWheels.leftWheel.commandIn;
        connect battery.powerOut to driveWheels.rightWheel.commandIn;
        connect battery.powerOut to cleaningAssembly.suctionFan.commandIn;
        connect battery.powerOut to cleaningAssembly.mainBrush.commandIn;
        connect battery.powerOut to cleaningAssembly.leftSideBrush.commandIn;
        connect battery.powerOut to cleaningAssembly.rightSideBrush.commandIn;

        // Sensor data to controller
        connect sensorSuite.frontIR.dataOut to navigationController.sensorDataIn;
        connect sensorSuite.leftIR.dataOut to navigationController.sensorDataIn;
        connect sensorSuite.rightIR.dataOut to navigationController.sensorDataIn;
        connect sensorSuite.bumper.dataOut to navigationController.sensorDataIn;
        connect sensorSuite.leftCliff.dataOut to navigationController.sensorDataIn;
        connect sensorSuite.rightCliff.dataOut to navigationController.sensorDataIn;
        connect sensorSuite.frontCliff.dataOut to navigationController.sensorDataIn;
        connect sensorSuite.dirt.dataOut to navigationController.sensorDataIn;

        // Controller commands to motors
        connect navigationController.motorCommandOut to driveWheels.leftWheel.commandIn;
        connect navigationController.motorCommandOut to driveWheels.rightWheel.commandIn;

        // Controller commands to cleaning assembly
        connect navigationController.cleaningCommandOut to cleaningAssembly.suctionFan.commandIn;
        connect navigationController.cleaningCommandOut to cleaningAssembly.mainBrush.commandIn;
        connect navigationController.cleaningCommandOut to cleaningAssembly.leftSideBrush.commandIn;
        connect navigationController.cleaningCommandOut to cleaningAssembly.rightSideBrush.commandIn;

        // Dock signal to controller
        connect dockSignalPort to navigationController.dockSignalIn;

        // Docking power to battery
        connect dockingPort to battery.chargingIn;

        // Battery status to controller
        connect battery.statusOut to navigationController.batteryStatusIn;

        // Main robot state machine
        state robotStateMachine {
            entry;
            then IdleState;
            state IdleState {
                entry;
                state = CleaningMode::idle;
                dockingStatus = DockingStatus::docked;
                // robot rests at dock, fully charged
            }
            transition from IdleState to ActiveCleaning
                when navigationController.sensorDataIn.reading.obstacleType != ObstacleType::none
                or battery.chargeLevel >= 100 [%];
            state ActiveCleaning {
                entry;
                state = CleaningMode::active;
                dockingStatus = DockingStatus::undocked;
                // systematic navigation and cleaning
            }
            transition from ActiveCleaning to SpotCleaning
                when sensorSuite.dirt.dataOut.reading.obstacleType == ObstacleType::dirt;
            state SpotCleaning {
                entry;
                state = CleaningMode::spot;
                // intensive cleaning of dirty area
            }
            transition from SpotCleaning to ActiveCleaning
                when sensorSuite.dirt.dataOut.reading.obstacleType != ObstacleType::dirt;
            transition from ActiveCleaning to ReturningToDock
                when battery.chargeLevel <= battery.lowThreshold;
            transition from SpotCleaning to ReturningToDock
                when battery.chargeLevel <= battery.lowThreshold;
            state ReturningToDock {
                entry;
                state = CleaningMode::returning;
                dockingStatus = DockingStatus::seeking;
                // navigate back to dock using IR dock signal
            }
            transition from ReturningToDock to ChargingState
                when dockSignalPort.signal.signalStrength > 0.9;
            state ChargingState {
                entry;
                state = CleaningMode::charging;
                dockingStatus = DockingStatus::docked;
                // recharging battery
            }
            transition from ChargingState to IdleState
                when battery.chargeLevel >= battery.fullThreshold;
        }

        satisfy CleaningRequirement by robotStateMachine;
        satisfy NavigationRequirement by navigationController;
        satisfy BatteryRequirement by battery;
        satisfy CliffSafetyRequirement by sensorSuite.frontCliff;
        satisfy SpotCleaningRequirement by sensorSuite.dirt;
    }

    // ===== Top-Level System =====

    part def VacuumSystem {
        part robot : RobotVacuum;
        part dock : ChargingDock;

        // Dock power to robot docking port
        connect dock.powerOut to robot.dockingPort;
        connect dock.dockSignalOut to robot.dockSignalPort;
        connect dock.dockingPort to robot.dockingPort;

        satisfy DockingRequirement by dock;
    }

}
