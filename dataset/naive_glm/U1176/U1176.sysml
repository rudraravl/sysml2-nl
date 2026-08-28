package ROVSystem {

    import SI::*;
    import ISQ::*;

    // ============================================================
    // Custom Value Types
    // ============================================================

    value type DataRate :> Real;
    value type Percentage :> Real;

    // ============================================================
    // Item Definitions
    // ============================================================

    item def ElectricPower {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute power : Power;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute commandType : String;
        attribute payload : String;
        attribute timestamp : String;
    }

    item def TelemetryData {
        attribute depth : Length;
        attribute heading : Angle;
        attribute batteryLevel : Percentage;
        attribute temperature : ThermodynamicTemperature;
        attribute pressure : Pressure;
        attribute timestamp : String;
    }

    item def VideoFrame {
        attribute frameId : Integer;
        attribute cameraId : String;
        attribute resolution : String;
        attribute timestamp : String;
    }

    item def SonarReading {
        attribute range : Length;
        attribute bearing : Angle;
        attribute intensity : Real;
    }

    item def NavigationData {
        attribute depth : Length;
        attribute heading : Angle;
        attribute pitch : Angle;
        attribute roll : Angle;
        attribute yaw : Angle;
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def PowerInPort {
        attribute ratedVoltage : ElectricPotential;
        attribute maxCurrent : ElectricCurrent;
        in power : ElectricPower;
    }

    port def PowerOutPort {
        attribute outputVoltage : ElectricPotential;
        attribute maxCurrent : ElectricCurrent;
        out power : ElectricPower;
    }

    port def RovCommPort {
        attribute bandwidth : DataRate;
        in commands : ControlCommand;
        out telemetry : TelemetryData;
        out video : VideoFrame;
        out sonar : SonarReading;
    }

    port def StationCommPort {
        attribute bandwidth : DataRate;
        out commands : ControlCommand;
        in telemetry : TelemetryData;
        in video : VideoFrame;
        in sonar : SonarReading;
    }

    // ============================================================
    // Connection Definitions
    // ============================================================

    connection def PowerLink {
        end source : PowerOutPort;
        end sink : PowerInPort;
    }

    connection def StationTetherCommLink {
        end stationEnd : StationCommPort;
        end tetherEnd : RovCommPort;
    }

    connection def TetherRovCommLink {
        end tetherEnd : StationCommPort;
        end rovEnd : RovCommPort;
    }

    // ============================================================
    // Structural Component Definitions
    // ============================================================

    part def Frame {
        attribute mass : Mass;
        attribute length : Length;
        attribute width : Length;
        attribute height : Length;
        attribute material : String;
    }

    part def PressureHousing {
        attribute maxPressure : Pressure;
        attribute material : String;
        attribute internalVolume : Volume;
    }

    // ============================================================
    // Sensor and Tool Definitions
    // ============================================================

    part def DepthSensor {
        attribute maxDepth : Length;
        attribute accuracy : Length;
        port def DepthOutPort {
            out depth : Length;
        }
        port depthOut : DepthOutPort;
        action def measureDepth;
    }

    part def Compass {
        attribute accuracy : Angle;
        port def CompassOutPort {
            out heading : Angle;
        }
        port headingOut : CompassOutPort;
        action def measureHeading;
    }

    part def Gyroscope {
        port def GyroOutPort {
            out pitch : Angle;
            out roll : Angle;
            out yaw : Angle;
        }
        port attitudeOut : GyroOutPort;
        action def measureAttitude;
    }

    part def Sonar {
        attribute range : Length;
        attribute frequency : Frequency;
        attribute beamWidth : Angle;
        port def SonarOutPort {
            out sonarReading : SonarReading;
        }
        port sonarOut : SonarOutPort;
        action def scan;
    }

    part def Camera {
        attribute resolution : String;
        attribute fps : Integer;
        attribute fieldOfView : Angle;
        port def CameraOutPort {
            out frame : VideoFrame;
        }
        port videoOut : CameraOutPort;
        action def captureFrame;
    }

    part def LightingSystem {
        attribute lumens : Integer;
        attribute isOn : Boolean;
        attribute beamAngle : Angle;
        action def turnOn;
        action def turnOff;
        action def adjustBrightness;
    }

    part def Thruster {
        attribute maxThrust : Force;
        attribute enabled : Boolean;
        action def activate;
        action def deactivate;
        action def setThrust;
    }

    part def ThrusterArray {
        attribute thrusterCount : Integer;
        part frontLeft : Thruster;
        part frontRight : Thruster;
        part rearLeft : Thruster;
        part rearRight : Thruster;
        part verticalLeft : Thruster;
        part verticalRight : Thruster;
        action def maneuver;
        action def stabilize;
        action def ascend;
        action def descend;
    }

    part def ManipulatorJoint {
        attribute minAngle : Angle;
        attribute maxAngle : Angle;
        attribute currentAngle : Angle;
        action def rotate;
    }

    part def Gripper {
        attribute isOpen : Boolean;
        attribute gripForce : Force;
        action def open;
        action def close;
        action def setGripForce;
    }

    part def ManipulatorArm {
        attribute reach : Length;
        part baseJoint : ManipulatorJoint;
        part shoulderJoint : ManipulatorJoint;
        part elbowJoint : ManipulatorJoint;
        part wristJoint : ManipulatorJoint;
        part endEffector : Gripper;
        action def extend;
        action def retract;
        action def moveToPosition;
        action def grasp;
        action def release;
    }

    part def BatteryPack {
        attribute capacity : Energy;
        attribute chargeLevel : Percentage;
        attribute voltage : ElectricPotential;
        port powerIn : PowerInPort;
        port powerOut : PowerOutPort;
        action def charge;
        action def discharge;
        action def monitorLevel;
    }

    part def NavigationSystem {
        part depthSensor : DepthSensor;
        part compass : Compass;
        part gyroscope : Gyroscope;
        port def NavOutPort {
            out navigationData : NavigationData;
        }
        port navOut : NavOutPort;
        action def computePosition;
    }

    part def VisionSystem {
        part frontCamera : Camera;
        part rearCamera : Camera;
        part lights : LightingSystem;
        action def captureAll;
        action def illuminateOn;
        action def illuminateOff;
    }

    // ============================================================
    // ROV Definition
    // ============================================================

    part def ROV {
        attribute maxDepth : Length;
        attribute mass : Mass;
        attribute length : Length;
        attribute width : Length;
        attribute height : Length;

        part frame : Frame;
        part housing : PressureHousing;
        part thrusters : ThrusterArray;
        part navigation : NavigationSystem;
        part sonar : Sonar;
        part vision : VisionSystem;
        part manipulator : ManipulatorArm;
        part battery : BatteryPack;

        port tetherPower : PowerInPort;
        port tetherComm : RovCommPort;

        attribute preDiveChecksPassed : Boolean;
        attribute deployed : Boolean;
        attribute operationalDepthReached : Boolean;
        attribute atSurface : Boolean;
        attribute criticalFailureDetected : Boolean;
        attribute inspectRequested : Boolean;
        attribute manipulateRequested : Boolean;
        attribute navigateRequested : Boolean;
        attribute ascendRequested : Boolean;

        state machine {
            state Standby;
            state Deployment;
            state Descent;
            state Operational {
                state Navigating;
                state Inspecting;
                state Manipulating;
                transition Navigating to Inspecting when inspectRequested;
                transition Inspecting to Manipulating when manipulateRequested;
                transition Manipulating to Navigating when navigateRequested;
                transition Inspecting to Navigating when navigateRequested;
                transition Manipulating to Inspecting when inspectRequested;
            }
            state Ascent;
            state Recovery;
            state Emergency;

            transition Standby to Deployment when preDiveChecksPassed;
            transition Deployment to Descent when deployed;
            transition Descent to Operational when operationalDepthReached;
            transition Operational to Ascent when ascendRequested;
            transition Ascent to Recovery when atSurface;
            transition Standby to Emergency when criticalFailureDetected;
            transition Deployment to Emergency when criticalFailureDetected;
            transition Descent to Emergency when criticalFailureDetected;
            transition Operational to Emergency when criticalFailureDetected;
            transition Ascent to Emergency when criticalFailureDetected;
            transition Emergency to Recovery when atSurface;
        }

        action def preDiveChecks;
        action def dive;
        action def operate;
        action def surface;
        action def emergencyAscent;
    }

    // ============================================================
    // Surface Control Station
    // ============================================================

    part def Display {
        attribute size : Length;
        attribute resolution : String;
        attribute purpose : String;
    }

    part def OperatorConsole {
        part mainDisplay : Display;
        part secondaryDisplay : Display;
        part telemetryDisplay : Display;
        attribute operatorControls : String;
        action def displayVideo;
        action def displayTelemetry;
        action def receiveOperatorInput;
    }

    part def PowerGenerator {
        attribute outputPower : Power;
        attribute outputVoltage : ElectricPotential;
        port def GeneratorOutPort {
            out generatedPower : ElectricPower;
        }
        port powerOut : GeneratorOutPort;
        action def generate;
    }

    part def CommunicationsEquipment {
        attribute bandwidth : DataRate;
        port def CommOutPort {
            out commands : ControlCommand;
            in telemetry : TelemetryData;
            in video : VideoFrame;
        }
        port commPort : CommOutPort;
        action def sendCommand;
        action def receiveTelemetry;
        action def receiveVideo;
    }

    part def SurfaceControlStation {
        attribute location : String;
        part operatorConsole : OperatorConsole;
        part powerGenerator : PowerGenerator;
        part comms : CommunicationsEquipment;

        port tetherPower : PowerOutPort;
        port tetherComm : StationCommPort;

        action def pilotRov;
        action def monitorRov;
    }

    // ============================================================
    // Umbilical Tether
    // ============================================================

    part def UmbilicalTether {
        attribute length : Length;
        attribute diameter : Length;
        attribute tensileStrength : Force;
        attribute maxVoltage : ElectricPotential;
        attribute maxCurrent : ElectricCurrent;
        attribute bandwidth : DataRate;

        port surfacePowerIn : PowerInPort;
        port surfaceCommIn : RovCommPort;
        port rovPowerOut : PowerOutPort;
        port rovCommOut : StationCommPort;

        action def transmitPower;
        action def transmitCommands;
        action def transmitTelemetry;
        action def transmitVideo;
    }

    // ============================================================
    // System Integration
    // ============================================================

    part def ROVSystem {
        part rov : ROV;
        part surfaceStation : SurfaceControlStation;
        part tether : UmbilicalTether;

        connection surfacePower : PowerLink {
            source :>> surfaceStation.tetherPower;
            sink :>> tether.surfacePowerIn;
        }

        connection surfaceComm : StationTetherCommLink {
            stationEnd :>> surfaceStation.tetherComm;
            tetherEnd :>> tether.surfaceCommIn;
        }

        connection rovPower : PowerLink {
            source :>> tether.rovPowerOut;
            sink :>> rov.tetherPower;
        }

        connection rovComm : TetherRovCommLink {
            tetherEnd :>> tether.rovCommOut;
            rovEnd :>> rov.tetherComm;
        }

        satisfy DepthRating by rov;
        satisfy Maneuverability by rov.thrusters;
        satisfy ManipulatorCapability by rov.manipulator;
        satisfy TetherTransmission by tether;
        satisfy EmergencyAscent by rov;
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def DepthRatingRequirement {
        doc /* The ROV shall be rated to operate at the specified maximum underwater depth. */;
        attribute maxOperatingDepth : Length;
    }

    requirement def ManeuverabilityRequirement {
        doc /* The ROV shall provide precise three-dimensional maneuvering using at least six thrusters. */;
        attribute minThrusterCount : Integer;
    }

    requirement def ManipulatorCapabilityRequirement {
        doc /* The manipulator arm shall reach and grasp underwater objects within the specified range and force. */;
        attribute minReach : Length;
        attribute maxGripForce : Force;
    }

    requirement def TetherTransmissionRequirement {
        doc /* The umbilical tether shall transmit high-voltage power and high-bandwidth data between the surface station and the ROV. */;
        attribute minBandwidth : DataRate;
        attribute maxPowerVoltage : ElectricPotential;
    }

    requirement def EmergencyAscentRequirement {
        doc /* Upon detection of a critical failure, the ROV shall automatically trigger an ascent to the surface. */;
    }

    requirement DepthRating : DepthRatingRequirement {
        attribute :>> maxOperatingDepth = 1000 [m];
    }

    requirement Maneuverability : ManeuverabilityRequirement {
        attribute :>> minThrusterCount = 6;
    }

    requirement ManipulatorCapability : ManipulatorCapabilityRequirement {
        attribute :>> minReach = 1.5 [m];
        attribute :>> maxGripForce = 200 [N];
    }

    requirement TetherTransmission : TetherTransmissionRequirement {
        attribute :>> minBandwidth = 100;
        attribute :>> maxPowerVoltage = 48 [V];
    }

    requirement EmergencyAscent : EmergencyAscentRequirement;
}
