package TaurobInspector {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    attribute def Length :> Real { unit 'm'; }
    attribute def Mass :> Real { unit 'kg'; }
    attribute def Velocity :> Real { unit 'm/s'; }
    attribute def Angle :> Real { unit 'rad'; }
    attribute def Temperature :> Real { unit 'K'; }
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'A'; }
    attribute def Energy :> Real { unit 'J'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def Frequency :> Real { unit 'Hz'; }
    attribute def Concentration :> Real { unit 'ppm'; }
    attribute def Distance :> Real { unit 'm'; }
    attribute def Torque :> Real { unit 'N*m'; }

    // ===== Item Definitions =====
    item def TelemetryData;
    item def VideoStream;
    item def SensorData;
    item def CommandMsg;
    item def PointCloud;
    item def MapData;
    item def IMUData;
    item def Image;
    item def ThermalImage;
    item def GasReading;
    item def Sample;
    item def PowerFlow;
    item def EmergencySignal;
    item def MissionPlan;
    item def InspectionReport;

    // ===== Port Definitions =====
    port def PowerOutPort { out PowerFlow; }
    port def PowerInPort { in PowerFlow; }
    port def DataOutPort { out SensorData; }
    port def DataInPort { in SensorData; }
    port def CommandPort { in CommandMsg; out TelemetryData; }
    port def VideoOutPort { out VideoStream; }
    port def ControlPort { in CommandMsg; out TelemetryData; }

    // ===== Requirements =====
    requirement def RuggedMobility {
        subject robot : TaurobInspector;
        requirement {
            doc /* The robot shall traverse rough terrain, climb inclines up to 45 degrees, and overcome obstacles up to 0.2 m. */
        }
    }

    requirement def MultiSensorInspection {
        subject robot : TaurobInspector;
        requirement {
            doc /* The robot shall provide visual, thermal, gas, LiDAR, and IMU data for inspection. */
        }
    }

    requirement def ManipulatorCapability {
        subject robot : TaurobInspector;
        requirement {
            doc /* The robot shall manipulate objects and collect samples using an articulated arm with gripper. */
        }
    }

    requirement def AutonomousOperation {
        subject robot : TaurobInspector;
        requirement {
            doc /* The onboard computer shall execute path planning, obstacle avoidance, and mission management. */
        }
    }

    requirement def SafetySystem {
        subject robot : TaurobInspector;
        requirement {
            doc /* A dedicated safety system shall monitor operations and trigger emergency stops on hazard detection. */
        }
    }

    requirement def Endurance {
        subject robot : TaurobInspector;
        requirement {
            doc /* The battery pack shall support extended operation of at least 4 hours. */
        }
    }

    requirement def SecureComms {
        subject robot : TaurobInspector;
        requirement {
            doc /* The robot shall maintain an encrypted wireless link for telemetry, video, and commands. */
        }
    }

    // ===== Part Definitions =====

    part def BatteryPack {
        attribute capacity : Energy = 500 * 1000 * 3600 [J];
        attribute currentVoltage : Voltage = 24 [V];
        attribute stateOfCharge : Real = 1.0;
        port powerOut : PowerOutPort;
        item flow powerFlow : PowerFlow out powerOut;
    }

    part def BatteryManagementSystem {
        attribute health : Real = 1.0;
        attribute temperature : Temperature = 298.15 [K];
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
        in item flow powerInFlow : PowerFlow in powerIn;
        out item flow powerOutFlow : PowerFlow out powerOut;
    }

    part def DriveMotor {
        attribute maxTorque : Torque = 50 [N*m];
        attribute currentSpeed : Velocity = 0 [m/s];
        port powerIn : PowerInPort;
        in item flow powerFlow : PowerFlow in powerIn;
        action def spin {
            in command : CommandMsg;
        }
    }

    part def SuspensionSystem {
        attribute stiffness : Real = 1000;
        attribute damping : Real = 50;
    }

    part def TrackedChassis {
        attribute mass : Mass = 35 [kg];
        attribute maxIncline : Angle = 0.785 [rad];
        attribute maxObstacleHeight : Length = 0.2 [m];
        part leftTrack;
        part rightTrack;
        part leftDriveMotor : DriveMotor;
        part rightDriveMotor : DriveMotor;
        part suspension : SuspensionSystem;
        port powerIn : PowerInPort;
        in item flow powerFlow : PowerFlow in powerIn;
        connection distributePower {
            powerFlow -> leftDriveMotor.powerIn.powerFlow;
            powerFlow -> rightDriveMotor.powerIn.powerFlow;
        }
    }

    part def VisualCamera {
        attribute resolution : Real = 1920 * 1080;
        attribute frameRate : Frequency = 30 [Hz];
        port videoOut : VideoOutPort;
        out item flow video : VideoStream out videoOut;
    }

    part def ThermalImager {
        attribute resolution : Real = 640 * 480;
        attribute temperatureRange : Temperature = 373.15 [K];
        port dataOut : DataOutPort;
        out item flow thermalData : ThermalImage out dataOut;
    }

    part def GasDetector {
        attribute targetGas : String;
        attribute threshold : Concentration = 50 [ppm];
        attribute currentReading : Concentration = 0 [ppm];
        port dataOut : DataOutPort;
        out item flow gasData : GasReading out dataOut;
    }

    part def LiDARUnit {
        attribute range : Distance = 100 [m];
        attribute scanRate : Frequency = 20 [Hz];
        port dataOut : DataOutPort;
        out item flow pointCloud : PointCloud out dataOut;
    }

    part def IMU {
        attribute updateRate : Frequency = 200 [Hz];
        port dataOut : DataOutPort;
        out item flow imuData : IMUData out dataOut;
    }

    part def SensorArray {
        part frontCamera : VisualCamera;
        part rearCamera : VisualCamera;
        part sideCamera : VisualCamera;
        part thermal : ThermalImager;
        part gasDetector1 : GasDetector { attribute targetGas = "CH4"; }
        part gasDetector2 : GasDetector { attribute targetGas = "CO"; }
        part gasDetector3 : GasDetector { attribute targetGas = "H2S"; }
        part lidar : LiDARUnit;
        part imu : IMU;
        port dataOut : DataOutPort;
        port videoOut : VideoOutPort;
        connection aggregateData {
            frontCamera.videoOut.video -> videoOut;
            rearCamera.videoOut.video -> videoOut;
            sideCamera.videoOut.video -> videoOut;
            thermal.dataOut.thermalData -> dataOut;
            gasDetector1.dataOut.gasData -> dataOut;
            gasDetector2.dataOut.gasData -> dataOut;
            gasDetector3.dataOut.gasData -> dataOut;
            lidar.dataOut.pointCloud -> dataOut;
            imu.dataOut.imuData -> dataOut;
        }
    }

    part def Joint {
        attribute maxAngle : Angle = 3.14 [rad];
        attribute currentAngle : Angle = 0 [rad];
        port powerIn : PowerInPort;
        in item flow powerFlow : PowerFlow in powerIn;
        action def rotate {
            in targetAngle : Angle;
        }
    }

    part def Gripper {
        attribute maxOpening : Length = 0.1 [m];
        attribute currentOpening : Length = 0.05 [m];
        port powerIn : PowerInPort;
        in item flow powerFlow : PowerFlow in powerIn;
        action def grasp {
            in object;
        }
        action def release;
    }

    part def ManipulatorArm {
        attribute degreesOfFreedom : Integer = 6;
        part joint1 : Joint;
        part joint2 : Joint;
        part joint3 : Joint;
        part joint4 : Joint;
        part joint5 : Joint;
        part joint6 : Joint;
        part gripper : Gripper;
        port powerIn : PowerInPort;
        in item flow powerFlow : PowerFlow in powerIn;
        connection distributePower {
            powerFlow -> joint1.powerIn.powerFlow;
            powerFlow -> joint2.powerIn.powerFlow;
            powerFlow -> joint3.powerIn.powerFlow;
            powerFlow -> joint4.powerIn.powerFlow;
            powerFlow -> joint5.powerIn.powerFlow;
            powerFlow -> joint6.powerIn.powerFlow;
            powerFlow -> gripper.powerIn.powerFlow;
        }
        action def moveTo {
            in targetPose;
        }
        action def collectSample {
            out sample : Sample;
        }
    }

    part def SafetyController {
        attribute hazardDetected : Boolean = false;
        port dataIn : DataInPort;
        port emergencyOut : ~DataOutPort;
        in item flow sensorInput : SensorData in dataIn;
        out item flow emergencySignal : EmergencySignal out emergencyOut;
        action def monitor;
        action def triggerEmergencyStop;
    }

    part def OnboardComputer {
        attribute cpuLoad : Real = 0.0;
        attribute memoryUsage : Real = 0.0;
        part safetySystem : SafetyController;
        port sensorDataIn : DataInPort;
        port commandPort : CommandPort;
        port controlOut : ~ControlPort;
        in item flow sensorInput : SensorData in sensorDataIn;
        in item flow commandInput : CommandMsg in commandPort;
        out item flow telemetryOutput : TelemetryData out commandPort;
        out item flow controlOutput : CommandMsg out controlOut;
        action def pathPlanning {
            in map : MapData;
            out plan : MissionPlan;
        }
        action def obstacleAvoidance {
            in pointCloud : PointCloud;
            out safePath;
        }
        action def missionManagement {
            in plan : MissionPlan;
            out report : InspectionReport;
        }
        action def processSensorData {
            in data : SensorData;
            out processed;
        }
    }

    part def CommunicationSystem {
        attribute range : Distance = 1000 [m];
        attribute encrypted : Boolean = true;
        attribute bandwidth : Frequency = 5.8e9 [Hz];
        port commandPort : CommandPort;
        port telemetryOut : ~CommandPort;
        in item flow commandInput : CommandMsg in commandPort;
        out item flow telemetryOutput : TelemetryData out commandPort;
        out item flow videoOutput : VideoStream out telemetryOut;
        action def transmit {
            in data : TelemetryData;
        }
        action def receive {
            out command : CommandMsg;
        }
    }

    part def PowerSystem {
        part battery : BatteryPack;
        part bms : BatteryManagementSystem;
        port powerOut : PowerOutPort;
        out item flow powerFlow : PowerFlow out powerOut;
        connection batteryToBms {
            battery.powerOut.powerFlow -> bms.powerIn.powerInFlow;
        }
        connection bmsToOutput {
            bms.powerOut.powerOutFlow -> powerFlow;
        }
    }

    // ===== Main System =====
    part def TaurobInspector {
        satisfy RuggedMobility;
        satisfy MultiSensorInspection;
        satisfy ManipulatorCapability;
        satisfy AutonomousOperation;
        satisfy SafetySystem;
        satisfy Endurance;
        satisfy SecureComms;

        attribute name : String = "Taurob Inspector";
        attribute maxSpeed : Velocity = 1.5 [m/s];
        attribute operatingTemperature : Temperature = 253.15 [K];

        part chassis : TrackedChassis;
        part sensors : SensorArray;
        part arm : ManipulatorArm;
        part computer : OnboardComputer;
        part comms : CommunicationSystem;
        part power : PowerSystem;

        port operatorLink : CommandPort;

        connection powerToChassis {
            power.powerOut.powerFlow -> chassis.powerIn.powerFlow;
        }
        connection powerToArm {
            power.powerOut.powerFlow -> arm.powerIn.powerFlow;
        }
        connection sensorsToComputer {
            sensors.dataOut -> computer.sensorDataIn.sensorInput;
        }
        connection sensorsToSafety {
            sensors.dataOut -> computer.safetySystem.dataIn.sensorInput;
        }
        connection commsToComputer {
            comms.commandPort.commandInput -> computer.commandPort.commandInput;
        }
        connection computerToComms {
            computer.commandPort.telemetryOutput -> comms.commandPort.telemetryOutput;
        }
        connection computerToChassis {
            computer.controlOut.controlOutput -> chassis.leftDriveMotor.spin.command;
        }
        connection commsToOperator {
            comms.commandPort <-> operatorLink;
        }

        // ===== State Machine =====
        state def Behavior {
            state Standby;
            state Charging;
            state Emergency;
            state Active;
            composite state Active {
                entry;
                state Navigating;
                state Inspecting;
                state Manipulating;
                transition init_nav {
                    from Active.entry to Navigating;
                }
                transition nav_to_insp {
                    from Navigating to Inspecting
                    when reachedInspectionPoint;
                }
                transition insp_to_manip {
                    from Inspecting to Manipulating
                    when manipulationRequired;
                }
                transition insp_to_nav {
                    from Inspecting to Navigating
                    when inspectionComplete and not manipulationRequired;
                }
                transition manip_to_nav {
                    from Manipulating to Navigating
                    when manipulationComplete;
                }
            }
            transition standby_to_active {
                from Standby to Active
                when missionReceived;
            }
            transition active_to_standby {
                from Active to Standby
                when missionComplete;
            }
            transition any_to_emergency {
                from Standby to Emergency
                when hazardDetected;
            }
            transition active_to_emergency {
                from Active to Emergency
                when hazardDetected;
            }
            transition charging_to_standby {
                from Charging to Standby
                when chargingComplete;
            }
            transition standby_to_charging {
                from Standby to Charging
                when batteryLow;
            }
            transition emergency_to_standby {
                from Emergency to Standby
                when hazardCleared;
            }
        }

        part behavior : Behavior;

        // ===== Mission Action =====
        action def executeMission {
            in plan : MissionPlan;
            out report : InspectionReport;
            perform action navigate {
                out reachedPoint;
            }
            perform action inspect {
                in location;
                out inspectionData : SensorData;
            }
            perform action manipulate {
                in target;
                out sample : Sample;
            }
            perform action transmitResults {
                in data : SensorData;
                in sample : Sample;
                out report : InspectionReport;
            }
        }
    }

    // ===== Operator (external) =====
    part def RemoteOperator {
        attribute id : String;
        port robotLink : CommandPort;
        action def sendMission {
            out plan : MissionPlan;
        }
        action def receiveReport {
            in report : InspectionReport;
        }
    }

    part inspector : TaurobInspector;
    part operator : RemoteOperator;

    connection operatorToRobot {
        operator.robotLink <-> inspector.operatorLink;
    }
}
