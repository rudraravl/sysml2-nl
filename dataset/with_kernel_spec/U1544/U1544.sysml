package SPHERES_System {
    private import SI::*;
    private import ISQ::*;
    private import ScalarValues::*;

    attribute def AngleValue :> Real;

    attribute def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    attribute def Velocity3D {
        attribute x : SpeedValue;
        attribute y : SpeedValue;
        attribute z : SpeedValue;
    }

    attribute def Attitude3D {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    attribute def TargetState {
        attribute position : Position3D;
        attribute velocity : Velocity3D;
    }

    attribute def StateEstimate {
        attribute position : Position3D;
        attribute velocity : Velocity3D;
        attribute attitude : Attitude3D;
    }

    attribute def ForceTorque6DOF {
        attribute fx : ForceValue;
        attribute fy : ForceValue;
        attribute fz : ForceValue;
        attribute tx : TorqueValue;
        attribute ty : TorqueValue;
        attribute tz : TorqueValue;
    }

    item def CO2Propellant;
    item def ElectricalPower;
    item def CommandData {
        attribute target : TargetState;
    }
    item def TelemetryData {
        attribute satelliteState : StateEstimate;
        attribute batteryCharge : Real;
        attribute propellantRemaining : MassValue;
    }
    item def ThrusterCommand {
        attribute thrusterId : Integer;
        attribute pulseDuration : TimeValue;
        attribute thrustLevel : ForceValue;
    }

    attribute def SigPowerOn;
    attribute def SigPowerOff;
    attribute def SigBeginMission;
    attribute def SigTargetAcquired;
    attribute def SigManeuverComplete;
    attribute def SigAbortMission;
    attribute def SigReturnToStandby;
    attribute def SigPropellantLow;

    port def PowerOutPort {
        out power : ElectricalPower;
    }
    port def PowerInPort {
        in power : ElectricalPower;
    }

    port def IMUOutputPort {
        out attitude : Attitude3D;
        out velocity : Velocity3D;
    }
    port def BeaconOutputPort {
        out range : LengthValue;
        out bearing : AngleValue;
    }
    port def SensorOutputPort {
        out attitude : Attitude3D;
        out velocity : Velocity3D;
        out ranges : LengthValue[5];
        out bearings : AngleValue[5];
    }
    port def SensorInputPort {
        in attitude : Attitude3D;
        in velocity : Velocity3D;
        in ranges : LengthValue[5];
        in bearings : AngleValue[5];
    }

    port def ThrusterControlOutPort {
        out command : ThrusterCommand;
    }
    port def ThrusterControlInPort {
        in command : ThrusterCommand;
    }

    port def PropellantOutPort {
        out propellant : CO2Propellant;
    }
    port def PropellantInPort {
        in propellant : CO2Propellant;
    }

    port def CommandInPort {
        in command : CommandData;
    }
    port def CommandOutPort {
        out command : CommandData;
    }
    port def TelemetryOutPort {
        out telemetry : TelemetryData;
    }
    port def TelemetryInPort {
        in telemetry : TelemetryData;
    }

    action def ProcessSensorData {
        in attitude : Attitude3D;
        in velocity : Velocity3D;
        in ranges : LengthValue[5];
        in bearings : AngleValue[5];
        out stateEstimate : StateEstimate;
    }
    action def ComputeControl {
        in stateEstimate : StateEstimate;
        in target : TargetState;
        out forcesTorques : ForceTorque6DOF;
    }
    action def AllocateThrusters {
        in forcesTorques : ForceTorque6DOF;
        out thrusterCommands : ThrusterCommand[12];
    }
    action def BuildTelemetry {
        in stateEstimate : StateEstimate;
        out telemetry : TelemetryData;
    }

    part def Battery {
        attribute capacity : EnergyValue = 360000 [J];
        attribute chargeLevel : Real = 1.0;
        port powerOut : PowerOutPort;
        perform action discharge {
            out power : ElectricalPower;
            first start;
            then action monitorLevel;
            then done;
        }
    }

    part def CO2Tank {
        attribute propellantMass : MassValue = 0.5 [kg];
        attribute pressure : PressureValue;
        port propellantOut : PropellantOutPort;
    }

    part def ThrusterModule {
        attribute thrusterId : Integer;
        attribute maxThrust : ForceValue = 0.1 [N];
        port commandIn : ThrusterControlInPort;
        port propellantIn : PropellantInPort;
        perform action fire {
            in command : ThrusterCommand;
            out pulse : CO2Propellant;
            first start;
            then action openValve;
            then action releaseGas;
            then action closeValve;
            then done;
        }
    }

    part def PropulsionSubsystem {
        attribute thrusterCount : Integer = 12;
        part thrusters[12] : ThrusterModule;
        part propellantTank : CO2Tank;
        port commandIn[12] : ThrusterControlInPort;
        port powerIn : PowerInPort;
        bind commandIn = thrusters.commandIn;
        connect propellantTank.propellantOut to thrusters.propellantIn;
        perform action distributePropellant {
            in propellant : CO2Propellant;
            out distributedPropellant : CO2Propellant[12];
            first start;
            then action regulatePressure;
            then action distributeToThrusters;
            then done;
        }
        satisfy SixDOFControlRequirement;
    }

    part def IMU {
        port dataOut : IMUOutputPort;
        port powerIn : PowerInPort;
        perform action sample {
            out attitude : Attitude3D;
            out velocity : Velocity3D;
            first start;
            then action readGyros;
            then action readAccels;
            then action integrateState;
            then done;
        }
    }

    part def UltrasonicBeacon {
        attribute beaconId : Integer;
        port dataOut : BeaconOutputPort;
        port powerIn : PowerInPort;
        perform action measure {
            out range : LengthValue;
            out bearing : AngleValue;
            first start;
            then action emitPulse;
            then action detectEcho;
            then action computeRangeBearing;
            then done;
        }
    }

    part def SensorSubsystem {
        part imu : IMU;
        part beacons[5] : UltrasonicBeacon;
        port sensorOut : SensorOutputPort;
        port powerIn : PowerInPort;
        bind sensorOut.attitude = imu.dataOut.attitude;
        bind sensorOut.velocity = imu.dataOut.velocity;
        bind sensorOut.ranges = beacons.dataOut.range;
        bind sensorOut.bearings = beacons.dataOut.bearing;
    }

    part def GNCComputer {
        port sensorIn : SensorInputPort;
        port thrusterOut[12] : ThrusterControlOutPort;
        port commandIn : CommandInPort;
        port telemetryOut : TelemetryOutPort;
        port powerIn : PowerInPort;
        perform action navigate {
            in attitude : Attitude3D;
            in velocity : Velocity3D;
            in ranges : LengthValue[5];
            in bearings : AngleValue[5];
            in target : TargetState;
            out thrusterCommands : ThrusterCommand[12];
            out telemetry : TelemetryData;
            action processSensors : ProcessSensorData {
                in attitude;
                in velocity;
                in ranges;
                in bearings;
                out stateEstimate;
            }
            action computeControl : ComputeControl {
                in stateEstimate;
                in target;
                out forcesTorques;
            }
            action allocateThrusters : AllocateThrusters {
                in forcesTorques;
                out thrusterCommands;
            }
            action buildTelemetry : BuildTelemetry {
                in stateEstimate;
                out telemetry;
            }
            first start;
            then processSensors;
            then computeControl;
            then allocateThrusters;
            then buildTelemetry;
            then done;
            bind processSensors.attitude = attitude;
            bind processSensors.velocity = velocity;
            bind processSensors.ranges = ranges;
            bind processSensors.bearings = bearings;
            bind computeControl.target = target;
            flow from processSensors.stateEstimate to computeControl.stateEstimate;
            flow from computeControl.forcesTorques to allocateThrusters.forcesTorques;
            flow from processSensors.stateEstimate to buildTelemetry.stateEstimate;
            bind thrusterCommands = allocateThrusters.thrusterCommands;
            bind telemetry = buildTelemetry.telemetry;
        }
    }

    part def CommunicationsSubsystem {
        port groundCommandIn : CommandInPort;
        port groundTelemetryOut : TelemetryOutPort;
        port commandOut : CommandOutPort;
        port telemetryIn : TelemetryInPort;
        port powerIn : PowerInPort;
        part antenna;
        part transceiver;
        connect transceiver to antenna;
        perform action transmitTelemetry {
            in telemetry : TelemetryData;
            out radioSignal : ElectricalPower;
            first start;
            then action encodeReport;
            then action sendReport;
            then done;
        }
        perform action receiveCommand {
            out command : CommandData;
            first start;
            then action listenForCommand;
            then action decodeCommand;
            then done;
        }
    }

    part def GroundStation {
        port commandOut : CommandOutPort;
        port telemetryIn : TelemetryInPort;
        part operator;
        perform action monitorTelemetry {
            in telemetry : TelemetryData;
            first start;
            then action receiveTelemetry;
            then action displayStatus;
            then done;
        }
        perform action issueCommand {
            out command : CommandData;
            first start;
            then action composeCommand;
            then action sendCommand;
            then done;
        }
    }

    part def SPHERESSatellite {
        attribute massActual : MassValue = 3.5 [kg];
        attribute diameter : LengthValue = 0.22 [m];
        attribute positionalError : LengthValue;
        attribute propellantConsumed : MassValue;
        attribute autonomousOperation : Boolean = true;
        attribute degreesOfFreedom : Integer = 6;

        part propulsion : PropulsionSubsystem;
        part sensors : SensorSubsystem;
        part gnc : GNCComputer;
        part battery : Battery;
        part comm : CommunicationsSubsystem;

        connect battery.powerOut to propulsion.powerIn;
        connect battery.powerOut to sensors.powerIn;
        connect battery.powerOut to gnc.powerIn;
        connect battery.powerOut to comm.powerIn;

        connect sensors.sensorOut to gnc.sensorIn;
        connect gnc.thrusterOut to propulsion.commandIn;
        connect comm.commandOut to gnc.commandIn;
        connect gnc.telemetryOut to comm.telemetryIn;

        state operationalStates {
            entry;
            then off;
            state off;
            accept SigPowerOn then standby;
            state standby;
            accept SigPowerOff then off;
            accept SigBeginMission then navigating;
            state navigating;
            accept SigTargetAcquired then proximityManeuver;
            state proximityManeuver;
            accept SigManeuverComplete then standby;
            accept SigAbortMission then emergency;
            state emergency;
            accept SigReturnToStandby then standby;
            accept SigPropellantLow then emergency;
            accept SigPowerOff then off;
        }

        satisfy PositionalAccuracyRequirement;
        satisfy PropellantEfficiencyRequirement;
        satisfy AutonomousNavigationRequirement;
    }

    part spheressTestbed {
        part satellite : SPHERESSatellite;
        part groundStation : GroundStation;
        connect groundStation.commandOut to satellite.comm.groundCommandIn;
        connect satellite.comm.groundTelemetryOut to groundStation.telemetryIn;
        satisfy MicrogravityOperationRequirement;
    }

    requirement def PositionalAccuracyRequirement {
        doc /* The satellite shall achieve positional accuracy within 2 cm during proximity maneuvers. */
        subject satellite : SPHERESSatellite;
        attribute maxPositionError : LengthValue = 0.02 [m];
    }

    requirement def PropellantEfficiencyRequirement {
        doc /* The satellite shall complete complex maneuvers while using a minimal amount of CO2 propellant. */
        subject satellite : SPHERESSatellite;
        attribute propellantBudget : MassValue = 0.08 [kg];
    }

    requirement def AutonomousNavigationRequirement {
        doc /* The satellite shall autonomously navigate to a target and perform proximity maneuvers without human intervention. */
        subject satellite : SPHERESSatellite;
    }

    requirement def SixDOFControlRequirement {
        doc /* The propulsion subsystem shall provide full six-degrees-of-freedom control. */
        subject propulsion : PropulsionSubsystem;
    }

    requirement def MicrogravityOperationRequirement {
        doc /* The system shall operate in the microgravity environment of the International Space Station. */
        subject testbed : spheressTestbed;
    }
}
