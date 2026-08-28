package AvionicsSuite {
    import ScalarValues::*;
    import Quantities::*;
    import Control::*;

    // ===== Value Types with Units =====
    attribute def AccelerationUnit :> Unit { value = 9.80665 [m/s^2]; }
    value type Acceleration :> Real { unit : AccelerationUnit; }
    attribute def AngularRateUnit :> Unit { value = 1 [rad/s]; }
    value type AngularRate :> Real { unit : AngularRateUnit; }
    attribute def PressureUnit :> Unit { value = 101325 [Pa]; }
    value type Pressure :> Real { unit : PressureUnit; }
    attribute def AltitudeUnit :> Unit { value = 1 [m]; }
    value type Altitude :> Real { unit : AltitudeUnit; }
    attribute def AirspeedUnit :> Unit { value = 1 [m/s]; }
    value type Airspeed :> Real { unit : AirspeedUnit; }
    attribute def HeadingUnit :> Unit { value = 1 [deg]; }
    value type Heading :> Real { unit : HeadingUnit; }
    attribute def LatitudeUnit :> Unit { value = 1 [deg]; }
    value type Latitude :> Real { unit : LatitudeUnit; }
    attribute def LongitudeUnit :> Unit { value = 1 [deg]; }
    value type Longitude :> Real { unit : LongitudeUnit; }
    attribute def AngleUnit :> Unit { value = 1 [deg]; }
    value type Angle :> Real { unit : AngleUnit; }
    attribute def ThrottleCmdUnit :> Unit { value = 1 [%]; }
    value type ThrottleCmd :> Real { unit : ThrottleCmdUnit; }
    attribute def FrequencyUnit :> Unit { value = 1 [MHz]; }
    value type Frequency :> Real { unit : FrequencyUnit; }

    // ===== Item Definitions =====
    item def SensorSample {
        attribute timestamp : Time;
    }
    item def AccelerationSample :> SensorSample {
        attribute accelX : Acceleration;
        attribute accelY : Acceleration;
        attribute accelZ : Acceleration;
    }
    item def RotationSample :> SensorSample {
        attribute rollRate : AngularRate;
        attribute pitchRate : AngularRate;
        attribute yawRate : AngularRate;
    }
    item def AirDataSample :> SensorSample {
        attribute staticPressure : Pressure;
        attribute dynamicPressure : Pressure;
        attribute totalTemp : Real;
    }
    item def NavigationSolution {
        attribute latitude : Latitude;
        attribute longitude : Longitude;
        attribute altitude : Altitude;
        attribute trueAirspeed : Airspeed;
        attribute heading : Heading;
        attribute timestamp : Time;
    }
    item def FlightPlan {
        attribute waypoints : List[0..*] of Waypoint;
        attribute activeLeg : Integer;
    }
    item def Waypoint {
        attribute name : String;
        attribute latitude : Latitude;
        attribute longitude : Longitude;
        attribute altitude : Altitude;
    }
    item def GuidanceCommand {
        attribute targetHeading : Heading;
        attribute targetAltitude : Altitude;
        attribute targetSpeed : Airspeed;
    }
    item def PilotInput {
        attribute stickPitch : Angle;
        attribute stickRoll : Angle;
        attribute rudderPedal : Angle;
        attribute throttleLever : ThrottleCmd;
    }
    item def ControlSurfaceCommand {
        attribute aileron : Angle;
        attribute rudder : Angle;
        attribute elevator : Angle;
        attribute throttle : ThrottleCmd;
    }
    item def DisplayData {
        attribute attitudeRoll : Angle;
        attribute attitudePitch : Angle;
        attribute airspeed : Airspeed;
        attribute altitude : Altitude;
        attribute heading : Heading;
        attribute navValid : Boolean;
        attribute alertText : String;
    }
    item def RadioMessage {
        attribute frequency : Frequency;
        attribute content : String;
        attribute direction : Enumeration { in; out; };
    }
    item def HealthStatus {
        attribute insOk : Boolean;
        attribute adcOk : Boolean;
        attribute fmsOk : Boolean;
        attribute fccOk : Boolean;
        attribute pfdOk : Boolean;
        attribute commOk : Boolean;
    }

    enumeration AvionicsMode { init; normal; degraded; failed; }

    // ===== Port Definitions =====
    port def NavDataOut {
        out navSolution : NavigationSolution;
        out health : HealthStatus;
    }
    port def NavDataIn {
        in navSolution : NavigationSolution;
    }
    port def GuidanceOut {
        out guidance : GuidanceCommand;
    }
    port def GuidanceIn {
        in guidance : GuidanceCommand;
    }
    port def PilotInputPort {
        in pilotInput : PilotInput;
    }
    port def ControlCmdOut {
        out cmd : ControlSurfaceCommand;
    }
    port def DisplayPort {
        out display : DisplayData;
    }
    port def SensorInPort {
        in sample : SensorSample;
    }
    port def RadioPort {
        inout message : RadioMessage;
    }
    port def HealthPort {
        out status : HealthStatus;
    }

    // ===== Requirements =====
    requirement def SafeOperationReq {
        doc "The avionics suite shall maintain safe operation under all flight phases."
        subject suite : IntegratedAvionicsSuite;
        objective {
            verify { suite.mode == AvionicsMode::normal or suite.mode == AvionicsMode::degraded; }
        }
    }
    requirement def NavigationAccuracyReq {
        doc "INS and ADC shall provide navigation solution within specified accuracy."
        subject nav : NavigationSubsystem;
        attribute maxPosError : Real = 10.0;
        attribute maxAltError : Real = 5.0;
        objective {
            verify { nav.positionError <= maxPosError and nav.altitudeError <= maxAltError; }
        }
    }
    requirement def FaultToleranceReq {
        doc "Suite shall detect failures and transition to degraded mode while alerting crew."
        subject suite : IntegratedAvionicsSuite;
        objective {
            verify { suite.mode == AvionicsMode::degraded implies suite.alertIssued; }
        }
    }
    requirement def DisplayReq {
        doc "PFD shall display attitude, airspeed, altitude, and heading."
        subject pfd : PrimaryFlightDisplay;
        objective {
            verify { pfd.lastDisplay.attitudeRoll != null and pfd.lastDisplay.airspeed != null; }
        }
    }
    requirement def CommReq {
        doc "Communication system shall support radio transmit and receive."
        subject comm : CommunicationSystem;
        objective {
            verify { comm.txEnabled and comm.rxEnabled; }
        }
    }

    // ===== Component Parts =====
    part def InertialNavigationSystem {
        port accelIn : SensorInPort;
        port gyroIn : SensorInPort;
        port navOut : NavDataOut;
        attribute positionError : Real;
        attribute altitudeError : Real;
        attribute calibrated : Boolean = false;
        attribute selfTestPassed : Boolean = false;

        action def ProcessInertial {
            in accel : AccelerationSample;
            in gyro : RotationSample;
            out solution : NavigationSolution;
            private attribute dt : Time = 0.01 [s];
            perform {
                // Integrate accelerations and rotations to compute nav solution
                solution.latitude := 0.0 [deg];
                solution.longitude := 0.0 [deg];
                solution.altitude := 0.0 [m];
                solution.trueAirspeed := 0.0 [m/s];
                solution.heading := 0.0 [deg];
                solution.timestamp := accel.timestamp;
            }
        }
        action def Calibrate {
            out ok : Boolean;
            perform { ok := true; }
        }
        action def SelfTest {
            out ok : Boolean;
            perform { ok := true; }
        }
        exhibit state InertialStateMachine {
            entry; then Off;
            state Off;
            state Initializing {
                entry { selfTestPassed := SelfTest().ok; calibrated := Calibrate().ok; }
            }
            state Operational;
            state Faulted;
            transition off_init initial Off to Initializing when true;
            transition init_op Initializing to Operational when selfTestPassed and calibrated;
            transition init_fault Initializing to Faulted when not selfTestPassed;
            transition op_fault Operational to Faulted when false;
        }
    }

    part def AirDataComputer {
        port airDataIn : SensorInPort;
        port navOut : NavDataOut;
        attribute altitudeError : Real;
        attribute calibrated : Boolean = false;
        attribute selfTestPassed : Boolean = false;

        action def ProcessAirData {
            in air : AirDataSample;
            out solution : NavigationSolution;
            perform {
                solution.altitude := (101325.0 [Pa] - air.staticPressure) / 12.0 [Pa/m];
                solution.trueAirspeed := sqrt(2.0 * air.dynamicPressure / 1.225 [kg/m^3]);
                solution.latitude := 0.0 [deg];
                solution.longitude := 0.0 [deg];
                solution.heading := 0.0 [deg];
                solution.timestamp := air.timestamp;
            }
        }
        action def Calibrate {
            out ok : Boolean;
            perform { ok := true; }
        }
        action def SelfTest {
            out ok : Boolean;
            perform { ok := true; }
        }
        exhibit state AirDataStateMachine {
            entry; then Off;
            state Off;
            state Initializing {
                entry { selfTestPassed := SelfTest().ok; calibrated := Calibrate().ok; }
            }
            state Operational;
            state Faulted;
            transition off_init initial Off to Initializing when true;
            transition init_op Initializing to Operational when selfTestPassed and calibrated;
            transition init_fault Initializing to Faulted when not selfTestPassed;
        }
    }

    part def FlightManagementSystem {
        port navIn : NavDataIn;
        port guidanceOut : GuidanceOut;
        attribute flightPlan : FlightPlan;
        attribute activeWaypoint : Integer = 0;
        attribute selfTestPassed : Boolean = false;

        action def ComputeGuidance {
            in nav : NavigationSolution;
            in plan : FlightPlan;
            out guidance : GuidanceCommand;
            perform {
                guidance.targetHeading := plan.waypoints[plan.activeLeg].latitude > nav.latitude ? 90.0 [deg] : 270.0 [deg];
                guidance.targetAltitude := plan.waypoints[plan.activeLeg].altitude;
                guidance.targetSpeed := 250.0 [m/s];
            }
        }
        action def LoadFlightPlan {
            in plan : FlightPlan;
            perform { flightPlan := plan; activeWaypoint := 0; }
        }
        action def SelfTest {
            out ok : Boolean;
            perform { ok := true; }
        }
        exhibit state FmsStateMachine {
            entry; then Off;
            state Off;
            state Initializing { entry { selfTestPassed := SelfTest().ok; } }
            state Planning;
            state Active;
            state Faulted;
            transition off_init initial Off to Initializing when true;
            transition init_plan Initializing to Planning when selfTestPassed;
            transition plan_active Planning to Active when flightPlan.waypoints->size() > 0;
            transition active_fault Active to Faulted when false;
        }
    }

    part def FlightControlComputer {
        port navIn : NavDataIn;
        port guidanceIn : GuidanceIn;
        port pilotIn : PilotInputPort;
        port controlOut : ControlCmdOut;
        attribute selfTestPassed : Boolean = false;
        attribute mode : AvionicsMode = AvionicsMode::init;

        action def BlendCommands {
            in guidance : GuidanceCommand;
            in pilot : PilotInput;
            out cmd : ControlSurfaceCommand;
            perform {
                cmd.aileron := pilot.stickRoll * 0.5;
                cmd.elevator := pilot.stickPitch * 0.5;
                cmd.rudder := pilot.rudderPedal * 0.5;
                cmd.throttle := pilot.throttleLever;
            }
        }
        action def SelfTest {
            out ok : Boolean;
            perform { ok := true; }
        }
        exhibit state FccStateMachine {
            entry; then Off;
            state Off;
            state Initializing { entry { selfTestPassed := SelfTest().ok; } }
            state Normal;
            state Degraded;
            state Faulted;
            transition off_init initial Off to Initializing when true;
            transition init_normal Initializing to Normal when selfTestPassed;
            transition normal_degraded Normal to Degraded when false;
            transition degraded_normal Degraded to Normal when true;
            transition normal_fault Normal to Faulted when false;
        }
    }

    part def PrimaryFlightDisplay {
        port navIn : NavDataIn;
        port displayOut : DisplayPort;
        attribute lastDisplay : DisplayData;
        attribute selfTestPassed : Boolean = false;

        action def RenderDisplay {
            in nav : NavigationSolution;
            in alert : String;
            out display : DisplayData;
            perform {
                display.attitudeRoll := 0.0 [deg];
                display.attitudePitch := 0.0 [deg];
                display.airspeed := nav.trueAirspeed;
                display.altitude := nav.altitude;
                display.heading := nav.heading;
                display.navValid := true;
                display.alertText := alert;
            }
        }
        action def SelfTest {
            out ok : Boolean;
            perform { ok := true; }
        }
        exhibit state PfdStateMachine {
            entry; then Off;
            state Off;
            state Initializing { entry { selfTestPassed := SelfTest().ok; } }
            state Operational;
            state Faulted;
            transition off_init initial Off to Initializing when true;
            transition init_op Initializing to Operational when selfTestPassed;
            transition op_fault Operational to Faulted when false;
        }
    }

    part def CommunicationSystem {
        port radioPort : RadioPort;
        attribute currentFreq : Frequency = 118.0 [MHz];
        attribute txEnabled : Boolean = true;
        attribute rxEnabled : Boolean = true;
        attribute selfTestPassed : Boolean = false;

        action def Transmit {
            in msg : RadioMessage;
            perform { msg.direction := out; }
        }
        action def Receive {
            out msg : RadioMessage;
            perform { msg.direction := in; msg.frequency := currentFreq; msg.content := ""; }
        }
        action def SetFrequency {
            in freq : Frequency;
            perform { currentFreq := freq; }
        }
        action def SelfTest {
            out ok : Boolean;
            perform { ok := true; }
        }
        exhibit state CommStateMachine {
            entry; then Off;
            state Off;
            state Initializing { entry { selfTestPassed := SelfTest().ok; } }
            state Standby;
            state Transmitting;
            state Receiving;
            state Faulted;
            transition off_init initial Off to Initializing when true;
            transition init_standby Initializing to Standby when selfTestPassed;
            transition standby_tx Standby to Transmitting when txEnabled;
            transition tx_standby Transmitting to Standby when true;
            transition standby_rx Standby to Receiving when rxEnabled;
            transition rx_standby Receiving to Standby when true;
            transition standby_fault Standby to Faulted when false;
        }
    }

    part def NavigationSubsystem {
        port navOut : NavDataOut;
        part ins : InertialNavigationSystem {
            port accelIn : SensorInPort;
            port gyroIn : SensorInPort;
            port navOut : NavDataOut;
        }
        part adc : AirDataComputer {
            port airDataIn : SensorInPort;
            port navOut : NavDataOut;
        }
        attribute positionError : Real;
        attribute altitudeError : Real;
        satisfy NavigationAccuracyReq by nav : NavigationSubsystem;
    }

    // ===== Top-level Integrated Avionics Suite =====
    part def IntegratedAvionicsSuite {
        port radioPort : RadioPort;
        port pilotIn : PilotInputPort;
        port controlOut : ControlCmdOut;
        port displayOut : DisplayPort;
        port healthOut : HealthPort;

        attribute mode : AvionicsMode = AvionicsMode::init;
        attribute alertIssued : Boolean = false;
        attribute health : HealthStatus;

        part navigation : NavigationSubsystem {
            part ins : InertialNavigationSystem;
            part adc : AirDataComputer;
        }
        part fms : FlightManagementSystem;
        part fcc : FlightControlComputer;
        part pfd : PrimaryFlightDisplay;
        part comm : CommunicationSystem;

        satisfy SafeOperationReq by suite : IntegratedAvionicsSuite;
        satisfy FaultToleranceReq by suite : IntegratedAvionicsSuite;
        satisfy DisplayReq by pfd : PrimaryFlightDisplay;
        satisfy CommReq by comm : CommunicationSystem;

        connection insNavToNavSub connect navigation.ins.navOut to navigation.navOut;
        connection adcNavToNavSub connect navigation.adc.navOut to navigation.navOut;
        connection navToFms connect navigation.navOut to fms.navIn;
        connection navToFcc connect navigation.navOut to fcc.navIn;
        connection navToPfd connect navigation.navOut to pfd.navIn;
        connection fmsToFcc connect fms.guidanceOut to fcc.guidanceIn;
        connection pilotToFcc connect pilotIn to fcc.pilotIn;
        connection fccToControl connect fcc.controlOut to controlOut;
        connection pfdToDisplay connect pfd.displayOut to displayOut;
        connection commRadio connect comm.radioPort to radioPort;

        action def InitializeSuite {
            out ok : Boolean;
            perform {
                // Power-on self-tests and sensor calibration sequence
                ok := navigation.ins.selfTestPassed and navigation.adc.selfTestPassed
                      and fms.selfTestPassed and fcc.selfTestPassed
                      and pfd.selfTestPassed and comm.selfTestPassed;
            }
        }
        action def MonitorHealth {
            out status : HealthStatus;
            perform {
                status.insOk := navigation.ins.selfTestPassed;
                status.adcOk := navigation.adc.selfTestPassed;
                status.fmsOk := fms.selfTestPassed;
                status.fccOk := fcc.selfTestPassed;
                status.pfdOk := pfd.selfTestPassed;
                status.commOk := comm.selfTestPassed;
            }
        }

        exhibit state SuiteStateMachine {
            entry; then PoweredOff;
            state PoweredOff;
            state Initializing {
                entry { mode := AvionicsMode::init; }
                do { InitializeSuite(); }
            }
            state Normal {
                entry { mode := AvionicsMode::normal; alertIssued := false; }
                do { MonitorHealth(); }
            }
            state Degraded {
                entry { mode := AvionicsMode::degraded; alertIssued := true; }
                do { MonitorHealth(); }
            }
            state Failed {
                entry { mode := AvionicsMode::failed; alertIssued := true; }
            }
            transition off_init initial PoweredOff to Initializing when true;
            transition init_normal Initializing to Normal when InitializeSuite().ok;
            transition init_failed Initializing to Failed when not InitializeSuite().ok;
            transition normal_degraded Normal to Degraded when not MonitorHealth().status.insOk or not MonitorHealth().status.adcOk;
            transition degraded_normal Degraded to Normal when MonitorHealth().status.insOk and MonitorHealth().status.adcOk;
            transition degraded_failed Degraded to Failed when not MonitorHealth().status.fccOk;
        }
    }
}
