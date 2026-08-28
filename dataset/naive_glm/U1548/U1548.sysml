package CapeCanaveralLaunchComplexModel {

    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    package ValueTypes {
        import ISQ::*;
        import SI::*;
        import ScalarValues::*;

        value type Altitude :> Length;
        value type Velocity :> Speed;
        value type Thrust :> Force;
        value type TemperatureValue :> ThermodynamicTemperature;
        value type FuelLevel :> Real;
        value type Probability :> Real;
        value type PayloadMass :> Mass;
        value type PropellantVolume :> Volume;
        value type FlowRate :> MassFlowRate;
    }

    package Enums {
        enum def CommandType { go; hold; launch; abort; }
        enum def PropellantType { LOX; LH2; RP1; }
        enum def WeatherCondition { go; hold; noGo; }
        enum def OrbitType { LEO; GTO; GEO; SSO; }
        enum def FlightPhase { preflight; fueling; countdown; ignition; liftoff; ascent; orbit; }
        enum def PadStateValue { idle; fueling; ready; countdown; released; }
    }

    package Items {
        import ValueTypes::*;
        import Enums::*;

        item def Telemetry {
            attribute altitude : Altitude;
            attribute velocity : Velocity;
            attribute thrust : Thrust;
            attribute fuelLevel : FuelLevel;
            attribute time : Time;
        }

        item def WeatherData {
            attribute windSpeed : Velocity;
            attribute temperature : TemperatureValue;
            attribute pressure : Pressure;
            attribute lightningRisk : Probability;
            attribute condition : WeatherCondition;
        }

        item def Command {
            attribute commandType : CommandType;
            attribute timestamp : Time;
        }

        item def Propellant {
            attribute propellantType : PropellantType;
            attribute volume : PropellantVolume;
            attribute mass : Mass;
            attribute temperature : TemperatureValue;
        }

        item def TrackingData {
            attribute positionX : Length;
            attribute positionY : Length;
            attribute positionZ : Length;
            attribute velocity : Velocity;
            attribute time : Time;
        }

        item def TrajectoryData {
            attribute nominalX : Length;
            attribute nominalY : Length;
            attribute nominalZ : Length;
            attribute deviationAngle : PlaneAngle;
            attribute time : Time;
        }
    }

    package Ports {
        import Items::*;

        port def TelemetryOut { out item telemetry : Telemetry; }
        port def TelemetryIn { in item telemetry : Telemetry; }
        port def CommandOut { out item command : Command; }
        port def CommandIn { in item command : Command; }
        port def WeatherIn { in item weather : WeatherData; }
        port def PropellantOut { out item propellant : Propellant; }
        port def PropellantIn { in item propellant : Propellant; }
        port def TrackingOut { out item trackingData : TrackingData; }
        port def TrackingIn { in item trackingData : TrackingData; }
        port def TrajectoryOut { out item trajectory : TrajectoryData; }
    }

    package Components {
        import ValueTypes::*;
        import Items::*;
        import Ports::*;
        import Enums::*;

        part def ServiceStructure {
            attribute height : Altitude;
            attribute retracted : Boolean = false;
            action retract { out attribute retracted : Boolean; }
        }

        part def HoldDownArms {
            attribute released : Boolean = false;
            attribute requiredThrust : Thrust;
            action release {
                in attribute thrust : Thrust;
                out attribute released : Boolean;
            }
        }

        part def FlameDeflector {
            attribute material : String;
            attribute maxTemperature : TemperatureValue;
        }

        part def MissionControl {
            port telemetryIn : TelemetryIn;
            port weatherIn : WeatherIn;
            port vehicleCommandOut : CommandOut;
            port padCommandOut : CommandOut;
            port trackingIn : TrackingIn;

            attribute currentCommand : CommandType;
            attribute lastTelemetry : Telemetry;
            attribute currentWeather : WeatherData;

            action def processTelemetry {
                in item telemetry : Telemetry;
                out item processedTelemetry : Telemetry;
            }

            action def evaluateWeather {
                in item weather : WeatherData;
                out attribute goNoGo : WeatherCondition;
            }

            action def issueCommand {
                in attribute commandType : CommandType;
                out item command : Command;
            }

            action def makeDecision {
                in item telemetry : Telemetry;
                in item weather : WeatherData;
                in item tracking : TrackingData;
                out attribute commandType : CommandType;
            }

            state missionControlState {
                state Monitoring;
                state Evaluating;
                state Go;
                state Hold;
                state Launch;
                state Abort;
                transition from Monitoring to Evaluating;
                transition from Evaluating to Go;
                transition from Evaluating to Hold;
                transition from Go to Launch;
                transition from Launch to Abort;
                transition from Hold to Go;
                transition from Hold to Abort;
            }
        }

        part def Payload {
            attribute payloadMass : PayloadMass;
            attribute targetOrbit : OrbitType;
            attribute deployed : Boolean = false;
            action deploy {
                out attribute deployed : Boolean;
            }
        }

        part def LaunchVehicleStage {
            attribute stageName : String;
            attribute fuelMass : Mass;
            attribute maxThrust : Thrust;
            attribute burnedOut : Boolean = false;
            action def ignite {
                out attribute thrust : Thrust;
            }
            action def separate;
        }

        part def LaunchVehicle {
            port telemetryOut : TelemetryOut;
            port commandIn : CommandIn;

            attribute totalMass : Mass;
            attribute maxThrust : Thrust;
            attribute currentThrust : Thrust;
            attribute currentAltitude : Altitude;
            attribute currentVelocity : Velocity;
            attribute fuelLevel : FuelLevel;
            attribute phase : FlightPhase;

            part payload : Payload;
            part stage1 : LaunchVehicleStage {
                :>> stageName = "Stage1";
            }
            part stage2 : LaunchVehicleStage {
                :>> stageName = "Stage2";
            }

            action def sendTelemetry {
                in attribute altitude : Altitude;
                in attribute velocity : Velocity;
                in attribute thrust : Thrust;
                in attribute fuel : FuelLevel;
                out item telemetry : Telemetry;
            }

            action def performPreflight {
                out attribute checksPassed : Boolean;
            }

            action def igniteEngines {
                out attribute thrust : Thrust;
            }

            action def stage1Separation;
            action def deployPayload {
                out attribute deployed : Boolean;
            }

            state vehicleState {
                state Prelaunch;
                state Fueling;
                state Countdown;
                state Ignition;
                state Liftoff;
                state Ascent;
                state Orbit;
                transition from Prelaunch to Fueling;
                transition from Fueling to Countdown;
                transition from Countdown to Ignition;
                transition from Ignition to Liftoff;
                transition from Liftoff to Ascent;
                transition from Ascent to Orbit;
            }
        }

        part def LaunchPad {
            port padCommandIn : CommandIn;
            port propellantIn : PropellantIn;

            attribute padState : PadStateValue;
            attribute padName : String;

            part serviceStructure : ServiceStructure;
            part holdDownArms : HoldDownArms;
            part flameDeflector : FlameDeflector;

            state padStateMachine {
                state Idle;
                state Fueling1;
                state Ready;
                state Countdown1;
                state Released1;
                transition from Idle to Fueling1;
                transition from Fueling1 to Ready;
                transition from Ready to Countdown1;
                transition from Countdown1 to Released1;
            }
        }

        part def PropellantFacility {
            port propellantOut : PropellantOut;

            attribute loxVolume : PropellantVolume;
            attribute lh2Volume : PropellantVolume;
            attribute rp1Volume : PropellantVolume;
            attribute loxTemperature : TemperatureValue;
            attribute lh2Temperature : TemperatureValue;
            attribute transferRate : FlowRate;

            action def transferPropellant {
                in attribute propellantType : PropellantType;
                in attribute volume : PropellantVolume;
                out item propellant : Propellant;
            }

            state facilityState {
                state Idle;
                state Storing;
                state Transferring;
                state Complete;
                transition from Idle to Storing;
                transition from Storing to Transferring;
                transition from Transferring to Complete;
                transition from Complete to Idle;
            }
        }

        part def TrackingStation {
            port trackingOut : TrackingOut;
            port telemetryIn : TelemetryIn;

            attribute stationName : String;
            attribute range : Length;
            attribute stationAltitude : Altitude;
            attribute isActive : Boolean = false;

            action def trackVehicle {
                in item telemetry : Telemetry;
                out item trackingData : TrackingData;
            }

            state trackingState {
                state Standby;
                state Active;
                state Tracking;
                state Complete;
                transition from Standby to Active;
                transition from Active to Tracking;
                transition from Tracking to Complete;
                transition from Complete to Standby;
            }
        }

        part def RangeSafety {
            port trackingIn : TrackingIn;
            port abortOut : CommandOut;

            attribute nominalTrajectory : TrajectoryData;
            attribute deviationThreshold : PlaneAngle;
            attribute abortActive : Boolean = true;

            action def monitorTrajectory {
                in item trackingData : TrackingData;
                in item nominal : TrajectoryData;
                out attribute deviation : PlaneAngle;
            }

            action def issueAbort {
                out item command : Command;
            }

            state rangeSafetyState {
                state Monitoring;
                state Evaluate;
                state Normal;
                state Abort;
                transition from Monitoring to Evaluate;
                transition from Evaluate to Normal;
                transition from Evaluate to Abort;
                transition from Normal to Monitoring;
                transition from Abort to Monitoring;
            }
        }
    }

    part def CapeCanaveralLaunchComplex {
        import Components::*;

        part missionControl : MissionControl;
        part launchVehicle : LaunchVehicle;
        part pad39A : LaunchPad { :>> padName = "39A"; }
        part pad39B : LaunchPad { :>> padName = "39B"; }
        part propellantFacility : PropellantFacility;
        part trackingStation : TrackingStation;
        part rangeSafety : RangeSafety;

        connect launchVehicle.telemetryOut to missionControl.telemetryIn;
        connect missionControl.vehicleCommandOut to launchVehicle.commandIn;
        connect missionControl.padCommandOut to pad39A.padCommandIn;
        connect propellantFacility.propellantOut to pad39A.propellantIn;
        connect trackingStation.trackingOut to missionControl.trackingIn;
        connect trackingStation.trackingOut to rangeSafety.trackingIn;
        connect rangeSafety.abortOut to launchVehicle.commandIn;
    }

    package Requirements {
        import ValueTypes::*;
        import Components::*;

        requirement def LaunchSequenceRequirement {
            subject launchComplex : CapeCanaveralLaunchComplex;
            doc /* The launch sequence must follow a structured sequence: pre-flight checks, fueling, countdown, ignition, liftoff, and ascent. */;
        }

        requirement def MissionControlRequirement {
            subject missionControl : MissionControl;
            doc /* Mission Control must receive real-time telemetry and weather data, and issue go/hold/launch/abort commands to the vehicle and launch pad systems. */;
        }

        requirement def LaunchVehicleRequirement {
            subject launchVehicle : LaunchVehicle;
            doc /* The launch vehicle must operate through prelaunch, fueling, countdown, ignition, liftoff, ascent, and orbit phases, continuously sending telemetry about its altitude, velocity, thrust, and fuel levels. */;
        }

        requirement def PayloadDeliveryRequirement {
            subject payload : Payload;
            doc /* The payload must be delivered to a specific target orbit. */;
        }

        requirement def LaunchPadRequirement {
            subject launchPad : LaunchPad;
            doc /* Each launch pad must include a service structure, hold-down arms that release the rocket at required thrust, and a flame deflector to manage engine energy. */;
        }

        requirement def PropellantFacilityRequirement {
            subject propellantFacility : PropellantFacility;
            doc /* The propellant facility must store and transfer LOX, LH2, and RP-1 propellant to the launch pad during pre-launch operations. */;
        }

        requirement def TrackingStationRequirement {
            subject trackingStation : TrackingStation;
            doc /* Tracking stations must track the vehicle flight path after liftoff using radar and relay position and velocity data as telemetry to Mission Control and Range Safety. */;
        }

        requirement def RangeSafetyRequirement {
            subject rangeSafety : RangeSafety;
            doc /* Range Safety must continuously monitor the rocket flight path and issue an immediate abort command to terminate the flight if the vehicle deviates from the planned trajectory and becomes a threat. */;
        }

        requirement def HoldDownArmsReleaseRequirement {
            subject launchPad : LaunchPad;
            doc /* Hold-down arms must release the vehicle only when engines reach required thrust. */;
        }
    }

}
