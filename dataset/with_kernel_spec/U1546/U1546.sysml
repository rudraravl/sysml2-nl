package IntegratedAvionicsSuite {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def AccelerationValue :> Real;
        attribute def RotationRateValue :> Real;
        attribute def AirPressureValue :> Real;
        attribute def AltitudeValue :> Real;
        attribute def AirspeedValue :> Real;
        attribute def HeadingValue :> Real;

        attribute def AttitudeValue {
            attribute roll : Real;
            attribute pitch : Real;
            attribute yaw : Real;
        }
        attribute def PositionValue {
            attribute latitude : Real;
            attribute longitude : Real;
        }

        item def SensorData {
            attribute acceleration : AccelerationValue;
            attribute rotationRate : RotationRateValue;
            attribute airPressure : AirPressureValue;
        }
        item def NavigationData {
            attribute position : PositionValue;
            attribute altitude : AltitudeValue;
            attribute airspeed : AirspeedValue;
            attribute heading : HeadingValue;
            attribute attitude : AttitudeValue;
        }
        item def GuidanceCommand {
            attribute targetHeading : HeadingValue;
            attribute targetAltitude : AltitudeValue;
            attribute targetSpeed : AirspeedValue;
        }
        item def PilotInput {
            attribute stickPitch : Real;
            attribute stickRoll : Real;
            attribute rudderPedal : Real;
            attribute throttleLever : Real;
        }
        item def ControlSurfaceCommand {
            attribute aileronDeflection : Real;
            attribute elevatorDeflection : Real;
            attribute rudderDeflection : Real;
        }
        item def ThrottleCommand {
            attribute throttleSetting : Real;
        }
        item def DisplayData {
            attribute attitude : AttitudeValue;
            attribute airspeed : AirspeedValue;
            attribute altitude : AltitudeValue;
            attribute heading : HeadingValue;
        }
        item def RadioTransmission;
        item def TransponderResponse;

        port def SensorDataPort { out item sensorData : SensorData; }
        port def NavDataPort { out item navData : NavigationData; }
        port def GuidancePort { out item guidanceCmd : GuidanceCommand; }
        port def PilotInputPort { in item pilotInput : PilotInput; }
        port def ControlCmdPort { out item controlCmd : ControlSurfaceCommand; }
        port def ThrottleCmdPort { out item throttleCmd : ThrottleCommand; }
        port def DisplayDataPort { out item displayData : DisplayData; }
        port def RadioPort { inout item transmission : RadioTransmission; }
        port def TransponderPort { inout item response : TransponderResponse; }

        part def Sensor {
            port sensorOut : SensorDataPort;
        }
        part def InertialNavigationSystem {
            port sensorIn : ~SensorDataPort;
            port navOut : NavDataPort;
            perform action processInertialData : ProcessInertialData;
        }
        part def AirDataComputer {
            port sensorIn : ~SensorDataPort;
            port navOut : NavDataPort;
            perform action processAirData : ProcessAirData;
        }
        part def FlightManagementSystem {
            port navIn : ~NavDataPort;
            port guidanceOut : GuidancePort;
            perform action manageFlightPlan : ManageFlightPlan;
        }
        part def FlightControlComputer {
            port navIn : ~NavDataPort;
            port guidanceIn : ~GuidancePort;
            port pilotIn : PilotInputPort;
            port controlOut : ControlCmdPort;
            port throttleOut : ThrottleCmdPort;
            port displayOut : DisplayDataPort;
            perform action computeControl : ComputeControl;
            exhibit state fccLifecycle : FCCLifecycle;
        }
        part def PrimaryFlightDisplay {
            port displayIn : ~DisplayDataPort;
            perform action renderDisplay : RenderDisplay;
        }
        part def CommunicationSystem {
            port radioPort : RadioPort;
            port transponderPort : TransponderPort;
            perform action handleRadio : HandleRadio;
            perform action handleTransponder : HandleTransponder;
        }
        part def ControlSurface {
            port cmdIn : ~ControlCmdPort;
        }
        part def Engine {
            port throttleIn : ~ThrottleCmdPort;
        }
        part def IntegratedAvionicsSuite;

        action def ProcessInertialData {
            in sensorData : SensorData;
            out navData : NavigationData;
        }
        action def ProcessAirData {
            in sensorData : SensorData;
            out navData : NavigationData;
        }
        action def ManageFlightPlan {
            in navData : NavigationData;
            out guidanceCmd : GuidanceCommand;
        }
        action def ComputeControl {
            in navData : NavigationData;
            in guidanceCmd : GuidanceCommand;
            in pilotInput : PilotInput;
            out controlCmd : ControlSurfaceCommand;
            out throttleCmd : ThrottleCommand;
            out displayData : DisplayData;
        }
        action def RenderDisplay {
            in displayData : DisplayData;
        }
        action def HandleRadio {
            inout transmission : RadioTransmission;
        }
        action def HandleTransponder {
            inout response : TransponderResponse;
        }
        action def PowerOnSelfTest;
        action def CalibrateSensors;
        action def MonitorHealth { out faultDetected : Boolean; }
        action def AlertCrew;
        action def PerformInitialization;

        attribute def PowerOnSignal;
        attribute def InitializationComplete;
        attribute def FailureDetected;
        attribute def RecoveryComplete;
        attribute def PowerOffSignal;

        state def FCCLifecycle;

        requirement def ReqInitialization {
            doc "The system shall perform power-on self-tests and sensor calibration during initialization."
        }
        requirement def ReqNavigation {
            doc "The INS and ADC shall process sensor data to calculate position, altitude, speed, and heading."
        }
        requirement def ReqGuidance {
            doc "The FMS shall use navigation data to generate autopilot guidance commands."
        }
        requirement def ReqControl {
            doc "The FCC shall combine guidance commands and pilot inputs to compute control surface and throttle adjustments."
        }
        requirement def ReqDisplay {
            doc "The PFD shall display essential flight information including attitude, airspeed, altitude, and heading."
        }
        requirement def ReqCommunication {
            doc "The Communication System shall handle radio transmissions and transponder operations."
        }
        requirement def ReqHealthMonitoring {
            doc "The system shall monitor its health and transition to degraded mode upon failure while alerting the crew."
        }
    }

    package Usages {
        private import Definitions::*;

        action powerOnSelfTest : PowerOnSelfTest;
        action calibrateSensors : CalibrateSensors;
        action monitorHealth : MonitorHealth { out faultDetected; }
        action alertCrew : AlertCrew;
        action performInit : PerformInitialization {
            first start;
            then action selfTest : PowerOnSelfTest;
            then action calibrate : CalibrateSensors;
            then done;
        }

        part avionicsSuite : IntegratedAvionicsSuite {
            part inertialSensor1 : Sensor;
            part inertialSensor2 : Sensor;
            part airDataSensor : Sensor;
            part ins : InertialNavigationSystem;
            part adc : AirDataComputer;
            part fms : FlightManagementSystem;
            part fcc : FlightControlComputer {
                exhibit state fccLifecycle : FCCLifecycle {
                    entry; then off;
                    state off;
                    transition offToInitializing
                        first off
                        accept PowerOnSignal
                        then initializing;
                    state initializing {
                        entry performInit;
                    }
                    transition initializingToNormal
                        first initializing
                        accept InitializationComplete
                        then normal;
                    state normal {
                        do monitorHealth { out faultDetected; }
                    }
                    transition normalToDegraded
                        first normal
                        when monitorHealth.faultDetected == true
                        do alertCrew
                        then degraded;
                    state degraded {
                        do monitorHealth { out faultDetected; }
                    }
                    transition degradedToNormal
                        first degraded
                        when monitorHealth.faultDetected == false
                        then normal;
                    transition normalToOff
                        first normal
                        accept PowerOffSignal
                        then off;
                }
            }
            part pfd : PrimaryFlightDisplay;
            part commSystem : CommunicationSystem;
            part ailerons : ControlSurface;
            part elevator : ControlSurface;
            part rudder : ControlSurface;
            part engine : Engine;

            connect inertialSensor1.sensorOut to ins.sensorIn;
            connect inertialSensor2.sensorOut to ins.sensorIn;
            connect airDataSensor.sensorOut to adc.sensorIn;

            connect ins.navOut to fms.navIn;
            connect ins.navOut to fcc.navIn;
            connect adc.navOut to fms.navIn;
            connect adc.navOut to fcc.navIn;

            connect fms.guidanceOut to fcc.guidanceIn;

            connect fcc.controlOut to ailerons.cmdIn;
            connect fcc.controlOut to elevator.cmdIn;
            connect fcc.controlOut to rudder.cmdIn;
            connect fcc.throttleOut to engine.throttleIn;

            connect fcc.displayOut to pfd.displayIn;

            satisfy ReqInitialization by fcc;
            satisfy ReqNavigation by ins, adc;
            satisfy ReqGuidance by fms;
            satisfy ReqControl by fcc;
            satisfy ReqDisplay by pfd;
            satisfy ReqCommunication by commSystem;
            satisfy ReqHealthMonitoring by fcc;
        }
    }
}
