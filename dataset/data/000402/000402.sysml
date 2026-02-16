package ArduPilotFlightControlSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def Position3D {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
    }

    attribute def Orientation {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
    }

    attribute def AngularRate {
        attribute rollRate : AngularVelocityValue;
        attribute pitchRate : AngularVelocityValue;
        attribute yawRate : AngularVelocityValue;
    }

    attribute def Acceleration3D {
        attribute ax : AccelerationValue;
        attribute ay : AccelerationValue;
        attribute az : AccelerationValue;
    }

    enum def FlightModeType {
        manual;
        stabilize;
        altHold;
        loiter;
        auto;
        rtl;
        land;
        guided;
    }

    enum def ArmingState {
        disarmed;
        preArm;
        armed;
    }

    item def IMUData {
        attribute angularRate : AngularRate;
        attribute acceleration : Acceleration3D;
        attribute timestamp : TimeValue;
    }

    item def GPSData {
        attribute position : Position3D;
        attribute groundSpeed : SpeedValue;
        attribute satelliteCount : Integer;
        attribute hdop : Real;
    }

    item def BarometerData {
        attribute pressure : PressureValue;
        attribute altitude : LengthValue;
        attribute temperature : TemperatureValue;
    }

    item def MagnetometerData {
        attribute heading : Real;
        attribute fieldStrength : Real;
    }

    item def BatteryStatus {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute remainingCapacity : Real;
    }

    item def MotorCommand {
        attribute throttle1 : Real;
        attribute throttle2 : Real;
        attribute throttle3 : Real;
        attribute throttle4 : Real;
    }

    item def ServoCommand {
        attribute aileron : Real;
        attribute elevator : Real;
        attribute rudder : Real;
    }

    item def RCInput {
        attribute roll : Real;
        attribute pitch : Real;
        attribute yaw : Real;
        attribute throttle : Real;
        attribute mode : FlightModeType;
    }

    item def TelemetryPacket {
        attribute position : Position3D;
        attribute orientation : Orientation;
        attribute batteryStatus : BatteryStatus;
        attribute flightMode : FlightModeType;
        attribute armingState : ArmingState;
    }

    item def MissionWaypoint {
        attribute targetPosition : Position3D;
        attribute targetSpeed : SpeedValue;
        attribute loiterTime : DurationValue;
        attribute acceptanceRadius : LengthValue;
    }

    port def SensorDataPort {
        out sensorData;
    }

    port def ActuatorCommandPort {
        in commandData;
    }

    port def CommunicationPort {
        in downlink;
        out uplink;
    }

    part def InertialMeasurementUnit {
        attribute sampleRate : FrequencyValue;
        attribute gyroRange : AngularVelocityValue;
        attribute accelRange : AccelerationValue;
        out port imuOutput : SensorDataPort;
    }

    part def GPSModule {
        attribute updateRate : FrequencyValue;
        attribute horizontalAccuracy : LengthValue;
        attribute verticalAccuracy : LengthValue;
        out port gpsOutput : SensorDataPort;
    }

    part def Barometer {
        attribute resolution : PressureValue;
        attribute altitudeAccuracy : LengthValue;
        out port baroOutput : SensorDataPort;
    }

    part def Magnetometer {
        attribute headingAccuracy : Real;
        out port magOutput : SensorDataPort;
    }

    part def BatteryMonitor {
        attribute voltageRange : ElectricPotentialValue;
        attribute currentRange : ElectricCurrentValue;
        out port batteryOutput : SensorDataPort;
    }

    part def RCReceiver {
        attribute channelCount : Integer;
        attribute signalFrequency : FrequencyValue;
        out port rcOutput : SensorDataPort;
    }

    part def TelemetryRadio {
        attribute linkFrequency : FrequencyValue;
        attribute maxRange : LengthValue;
        attribute dataRate : Real;
        in port telemetryInput : CommunicationPort;
        out port telemetryOutput : CommunicationPort;
    }

    part def ElectronicSpeedController {
        attribute maxCurrent : ElectricCurrentValue;
        attribute responseTime : DurationValue;
        in port escInput : ActuatorCommandPort;
        out port motorOutput;
    }

    part def BrushlessMotor {
        attribute kvRating : Real;
        attribute maxPower : PowerValue;
        attribute efficiency : Real;
        in port motorInput;
    }

    part def Servo {
        attribute maxTorque : Real;
        attribute operatingSpeed : Real;
        in port servoInput : ActuatorCommandPort;
    }

    part def FlightControllerBoard {
        attribute processorFrequency : FrequencyValue;
        attribute ramSize : Real;
        attribute flashSize : Real;
        attribute controlLoopRate : FrequencyValue;

        in port sensorInputs : SensorDataPort;
        in port rcInputPort : SensorDataPort;
        in port telemetryInputPort : CommunicationPort;
        out port actuatorOutputs : ActuatorCommandPort;
        out port telemetryOutputPort : CommunicationPort;

        part imuSensor : InertialMeasurementUnit {
            attribute :>> sampleRate = 1000.0 [Hz];
            attribute :>> gyroRange = 34.9 [rad/s];
            attribute :>> accelRange = 16.0 [m/s^2];
        }

        part gpsSensor : GPSModule {
            attribute :>> updateRate = 10.0 [Hz];
            attribute :>> horizontalAccuracy = 2.5 [m];
            attribute :>> verticalAccuracy = 5.0 [m];
        }

        part baroSensor : Barometer {
            attribute :>> resolution = 10.0 [Pa];
            attribute :>> altitudeAccuracy = 0.5 [m];
        }

        part magSensor : Magnetometer {
            attribute :>> headingAccuracy = 0.035;
        }

        perform action flightControlLoop;
    }

    action def ReadSensorData {
        out imuData : IMUData;
        out gpsData : GPSData;
        out baroData : BarometerData;
        out magData : MagnetometerData;
        out batteryData : BatteryStatus;
    }

    action def StateEstimation {
        in imuData : IMUData;
        in gpsData : GPSData;
        in baroData : BarometerData;
        in magData : MagnetometerData;
        out estimatedPosition : Position3D;
        out estimatedOrientation : Orientation;
        out estimatedVelocity : SpeedValue;
    }

    action def ModeManagement {
        in rcInput : RCInput;
        in currentState : ArmingState;
        in batteryStatus : BatteryStatus;
        out activeMode : FlightModeType;
        out armingCommand : ArmingState;
    }

    action def NavigationControl {
        in currentPosition : Position3D;
        in targetWaypoint : MissionWaypoint;
        in currentMode : FlightModeType;
        out desiredPosition : Position3D;
        out desiredVelocity : SpeedValue;
        out desiredHeading : Real;
    }

    action def GuidanceControl {
        in currentPosition : Position3D;
        in currentOrientation : Orientation;
        in desiredPosition : Position3D;
        in desiredVelocity : SpeedValue;
        in desiredHeading : Real;
        out desiredAttitude : Orientation;
        out desiredThrottle : Real;
    }

    action def AttitudeControl {
        in currentOrientation : Orientation;
        in currentAngularRate : AngularRate;
        in desiredAttitude : Orientation;
        in desiredThrottle : Real;
        out motorCommands : MotorCommand;
        out servoCommands : ServoCommand;
    }

    action def SendActuatorCommands {
        in motorCommands : MotorCommand;
        in servoCommands : ServoCommand;
    }

    action def TransmitTelemetry {
        in telemetryData : TelemetryPacket;
    }

    action def FlightControlCycle {
        first start;
        then merge controlLoop;

        then action readSensors : ReadSensorData {
            out imuData : IMUData;
            out gpsData : GPSData;
            out baroData : BarometerData;
            out magData : MagnetometerData;
            out batteryData : BatteryStatus;
        }

        then action estimateState : StateEstimation {
            in imuData = readSensors.imuData;
            in gpsData = readSensors.gpsData;
            in baroData = readSensors.baroData;
            in magData = readSensors.magData;
            out estimatedPosition : Position3D;
            out estimatedOrientation : Orientation;
            out estimatedVelocity : SpeedValue;
        }

        then action manageMode : ModeManagement {
            in rcInput : RCInput;
            in currentState : ArmingState;
            in batteryStatus = readSensors.batteryData;
            out activeMode : FlightModeType;
            out armingCommand : ArmingState;
        }

        then action navigate : NavigationControl {
            in currentPosition = estimateState.estimatedPosition;
            in targetWaypoint : MissionWaypoint;
            in currentMode = manageMode.activeMode;
            out desiredPosition : Position3D;
            out desiredVelocity : SpeedValue;
            out desiredHeading : Real;
        }

        then action guide : GuidanceControl {
            in currentPosition = estimateState.estimatedPosition;
            in currentOrientation = estimateState.estimatedOrientation;
            in desiredPosition = navigate.desiredPosition;
            in desiredVelocity = navigate.desiredVelocity;
            in desiredHeading = navigate.desiredHeading;
            out desiredAttitude : Orientation;
            out desiredThrottle : Real;
        }

        then action controlAttitude : AttitudeControl {
            in currentOrientation = estimateState.estimatedOrientation;
            in currentAngularRate : AngularRate;
            in desiredAttitude = guide.desiredAttitude;
            in desiredThrottle = guide.desiredThrottle;
            out motorCommands : MotorCommand;
            out servoCommands : ServoCommand;
        }

        then action sendCommands : SendActuatorCommands {
            in motorCommands = controlAttitude.motorCommands;
            in servoCommands = controlAttitude.servoCommands;
        }

        then action transmitTelemetry : TransmitTelemetry {
            in telemetryData : TelemetryPacket;
        }

        then controlLoop;
    }

    action def RunDiagnostics;
    action def CalibrateSensors;
    action def MonitorPreArmChecks;
    action def WaitForThrottle;
    action def ExecuteFlightPlan;
    action def ReturnToLaunchEmergency;
    action def ReturnToLaunchFailsafe;
    action def DescendToGround;
    action def MotorsOff;

    state def ArduPilotStateMachine {
        entry; then powerOn;

        state powerOn;
        then selfTest;

        state selfTest {
            do action runDiagnostics : RunDiagnostics;
        }
        then sensorCalibration;

        state sensorCalibration {
            do action calibrateSensors : CalibrateSensors;
        }
        then preArmed;

        state preArmed {
            do action monitorPreArmChecks : MonitorPreArmChecks;
        }
        accept when armingConditionsMet;
        then armed;

        state armed {
            do action waitForThrottle : WaitForThrottle;
        }
        accept when throttleEngaged;
        then flying;

        state flying {
            do action flightControl : FlightControlCycle;
        }
        accept when batteryLevelCritical;
        then emergencyRTL;

        state emergencyRTL {
            do action returnToLaunchEmergency : ReturnToLaunchEmergency;
        }
        accept when homePositionReached;
        then emergencyLanding;

        state emergencyLanding {
            do action descendToGround : DescendToGround;
        }
        accept when touchdownDetected;
        then disarmed;

        state disarmed {
            do action motorsOff : MotorsOff;
        }
    }

    part def QuadcopterFrame {
        attribute frameMass : MassValue;
        attribute armLength : LengthValue;
    }

    part def ArduPilotQuadcopter {
        attribute totalMass : MassValue;
        attribute maxFlightTime : DurationValue;
        attribute maxPayloadMass : MassValue;

        part flightController : FlightControllerBoard {
            attribute :>> processorFrequency = 216.0 [MHz];
            attribute :>> ramSize = 512.0;
            attribute :>> flashSize = 2048.0;
            attribute :>> controlLoopRate = 400.0 [Hz];
        }

        part frame : QuadcopterFrame {
            attribute :>> frameMass = 450.0 [g];
            attribute :>> armLength = 0.25 [m];
        }

        part rcReceiver : RCReceiver {
            attribute :>> channelCount = 16;
            attribute :>> signalFrequency = 2400.0 [MHz];
        }

        part telemetryRadio : TelemetryRadio {
            attribute :>> linkFrequency = 915.0 [MHz];
            attribute :>> maxRange = 1000.0 [m];
            attribute :>> dataRate = 57600.0;
        }

        part batteryMonitor : BatteryMonitor {
            attribute :>> voltageRange = 25.0 [V];
            attribute :>> currentRange = 90.0 [A];
        }

        part esc1 : ElectronicSpeedController {
            attribute :>> maxCurrent = 30.0 [A];
            attribute :>> responseTime = 0.002 [s];
        }

        part esc2 : ElectronicSpeedController {
            attribute :>> maxCurrent = 30.0 [A];
            attribute :>> responseTime = 0.002 [s];
        }

        part esc3 : ElectronicSpeedController {
            attribute :>> maxCurrent = 30.0 [A];
            attribute :>> responseTime = 0.002 [s];
        }

        part esc4 : ElectronicSpeedController {
            attribute :>> maxCurrent = 30.0 [A];
            attribute :>> responseTime = 0.002 [s];
        }

        part motor1 : BrushlessMotor {
            attribute :>> kvRating = 920.0;
            attribute :>> maxPower = 300.0 [W];
            attribute :>> efficiency = 0.85;
        }

        part motor2 : BrushlessMotor {
            attribute :>> kvRating = 920.0;
            attribute :>> maxPower = 300.0 [W];
            attribute :>> efficiency = 0.85;
        }

        part motor3 : BrushlessMotor {
            attribute :>> kvRating = 920.0;
            attribute :>> maxPower = 300.0 [W];
            attribute :>> efficiency = 0.85;
        }

        part motor4 : BrushlessMotor {
            attribute :>> kvRating = 920.0;
            attribute :>> maxPower = 300.0 [W];
            attribute :>> efficiency = 0.85;
        }

        connection rcToController connect rcReceiver.rcOutput to flightController.rcInputPort;
        connection telemetryToController connect telemetryRadio.telemetryOutput to flightController.telemetryInputPort;
        connection controllerToTelemetry connect flightController.telemetryOutputPort to telemetryRadio.telemetryInput;
        connection batteryToController connect batteryMonitor.batteryOutput to flightController.sensorInputs;

        connection controllerToESC1 connect flightController.actuatorOutputs to esc1.escInput;
        connection controllerToESC2 connect flightController.actuatorOutputs to esc2.escInput;
        connection controllerToESC3 connect flightController.actuatorOutputs to esc3.escInput;
        connection controllerToESC4 connect flightController.actuatorOutputs to esc4.escInput;

        connection esc1ToMotor1 connect esc1.motorOutput to motor1.motorInput;
        connection esc2ToMotor2 connect esc2.motorOutput to motor2.motorInput;
        connection esc3ToMotor3 connect esc3.motorOutput to motor3.motorInput;
        connection esc4ToMotor4 connect esc4.motorOutput to motor4.motorInput;

        assert constraint massBalance {
            totalMass == frame.frameMass + flightController.imuSensor.sampleRate * 0.02 [g] + 
                         motor1.maxPower * 0.1 [g/W] + motor2.maxPower * 0.1 [g/W] + 
                         motor3.maxPower * 0.1 [g/W] + motor4.maxPower * 0.1 [g/W]
        }
    }

    requirement <'REQ-AP-001'> autonomousFlightCapability {
        doc /* The ArduPilot system shall provide autonomous flight capability including 
             * waypoint navigation, automatic takeoff and landing, and return-to-launch 
             * functionality for unmanned aerial vehicles. */
        subject quadcopter : ArduPilotQuadcopter;
    }

    requirement <'REQ-AP-002'> multiModeOperation {
        doc /* The system shall support multiple flight modes including manual, stabilize, 
             * altitude hold, loiter, auto, RTL, land, and guided modes. */
        subject quadcopter : ArduPilotQuadcopter;
    }

    requirement <'REQ-AP-003'> sensorFusionAccuracy {
        doc /* The system shall fuse IMU, GPS, barometer, and magnetometer data to provide 
             * position accuracy within 2.5 meters horizontally and 1.0 meter vertically. */
        subject quadcopter : ArduPilotQuadcopter;

        assert constraint {
            quadcopter.flightController.gpsSensor.horizontalAccuracy <= 2.5 [m] and
            quadcopter.flightController.baroSensor.altitudeAccuracy <= 1.0 [m]
        }
    }

    requirement <'REQ-AP-004'> controlLoopPerformance {
        doc /* The flight control loop shall execute at a minimum rate of 400 Hz to ensure 
             * stable attitude control and rapid response to disturbances. */
        subject quadcopter : ArduPilotQuadcopter;

        assert constraint {
            quadcopter.flightController.controlLoopRate >= 400.0 [Hz]
        }
    }

    requirement <'REQ-AP-005'> failsafeOperation {
        doc /* The system shall implement failsafe modes including battery failsafe, 
             * RC link loss failsafe, and GPS loss failsafe with automatic RTL. */
        subject quadcopter : ArduPilotQuadcopter;
    }

    requirement <'REQ-AP-006'> telemetryReporting {
        doc /* The system shall transmit telemetry data including position, orientation, 
             * battery status, and flight mode at a minimum rate of 1 Hz. */
        subject quadcopter : ArduPilotQuadcopter;

        assert constraint {
            quadcopter.telemetryRadio.dataRate >= 9600.0
        }
    }

    part arduPilotSystem : ArduPilotQuadcopter {
        attribute :>> totalMass = 1500.0 [g];
        attribute :>> maxFlightTime = 20.0 [min];
        attribute :>> maxPayloadMass = 500.0 [g];
    }

    satisfy autonomousFlightCapability by arduPilotSystem;
    satisfy multiModeOperation by arduPilotSystem;
    satisfy sensorFusionAccuracy by arduPilotSystem;
    satisfy controlLoopPerformance by arduPilotSystem;
    satisfy failsafeOperation by arduPilotSystem;
    satisfy telemetryReporting by arduPilotSystem;
}
