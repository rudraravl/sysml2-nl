package AutonomousDroneSystem {
    import ScalarValues::*;
    import ISQ::*;

    // --- Items ---
    item def Electricity;
    item def GPSData;
    item def Waypoint;
    item def TelemetryData;
    item def RemoteCommand;
    item def ImageData;
    item def EnvironmentalData;
    item def MotorControlSignal;
    item def ReleaseCommand;
    item def Package;

    // --- Value Types ---
    attribute def PowerValue :> Real { :>> unit = W; }
    attribute def EnergyValue :> Real { :>> unit = J; }
    attribute def VoltageValue :> Real { :>> unit = V; }
    attribute def Percentage :> Real;

    // --- Ports ---
    port def PowerInPort {
        in item power : Electricity;
    }
    port def PowerOutPort {
        out item power : Electricity;
    }
    port def NavDataPort {
        out item gps : GPSData;
        out item waypoint : Waypoint;
    }
    port def TelemetryPort {
        out item telemetry : TelemetryData;
    }
    port def CommandPort {
        in item command : RemoteCommand;
    }
    port def FlightControlPort {
        out item motorCmd : MotorControlSignal;
    }
    port def SensorDataPort {
        out item image : ImageData;
        out item envData : EnvironmentalData;
    }
    port def PayloadPort {
        in item releaseCmd : ReleaseCommand;
    }

    // --- Subcomponents ---
    part def Motor {
        port powerIn : PowerInPort;
        port controlIn : FlightControlPort;
        attribute thrust : PowerValue;
        attribute rpm : Real;
    }

    part def PropulsionSystem {
        part motors[4] : Motor;
        port powerIn : PowerInPort;
        port controlIn : FlightControlPort;
        attribute landed : Boolean;

        connect powerIn to motors.powerIn;
        connect controlIn to motors.controlIn;
    }

    part def FlightControlModule {
        port powerIn : PowerInPort;
        port navIn : NavDataPort;
        port cmdIn : CommandPort;
        port motorOut : FlightControlPort;
        port sensorIn : SensorDataPort;
        port payloadOut : PayloadPort;
        attribute adjusting : Boolean;
        attribute thrustCalculation : PowerValue;
    }

    part def NavigationModule {
        port powerIn : PowerInPort;
        port navOut : NavDataPort;
        attribute atDestination : Boolean;
        attribute atBase : Boolean;
        attribute patrolComplete : Boolean;
        attribute currentLocation : GPSData;
        attribute plannedRoute : Waypoint[0..*];
    }

    part def CommunicationModule {
        port powerIn : PowerInPort;
        port cmdIn : CommandPort;
        port dataIn : SensorDataPort;
        port telemetryOut : TelemetryPort;
        attribute receivedCommand : String;
    }

    part def SensorUnit {
        port powerIn : PowerInPort;
        port dataOut : SensorDataPort;
        attribute resolution : Real;
    }

    part def SensingModule {
        part sensors[2] : SensorUnit;
        port powerIn : PowerInPort;
        port dataOut : SensorDataPort;
        attribute surveyComplete : Boolean;

        connect powerIn to sensors.powerIn;
        connect sensors.dataOut to dataOut;
    }

    part def PayloadModule {
        port powerIn : PowerInPort;
        port releaseCmd : PayloadPort;
        attribute hasPackage : Boolean;
        attribute packageReleased : Boolean;
        part cargo : Package;
    }

    part def PowerModule {
        port powerOut : PowerOutPort;
        attribute batteryLevel : Percentage;
        attribute totalEnergy : EnergyValue;
        attribute outputVoltage : VoltageValue;
    }

    // --- Main System ---
    part def AutonomousDrone {
        part powerSystem : PowerModule;
        part propulsion : PropulsionSystem;
        part flightControl : FlightControlModule;
        part navigation : NavigationModule;
        part communication : CommunicationModule;
        part sensing : SensingModule;
        part payload : PayloadModule;

        attribute batteryThreshold : Percentage = 20.0;
        attribute criticalFailure : Boolean = false;
        attribute missionType : String = "none";

        // Power Distribution
        connect powerSystem.powerOut to propulsion.powerIn;
        connect powerSystem.powerOut to flightControl.powerIn;
        connect powerSystem.powerOut to navigation.powerIn;
        connect powerSystem.powerOut to communication.powerIn;
        connect powerSystem.powerOut to sensing.powerIn;
        connect powerSystem.powerOut to payload.powerIn;

        // Data and Control Routing
        connect navigation.navOut to flightControl.navIn;
        connect communication.cmdIn to flightControl.cmdIn;
        connect flightControl.motorOut to propulsion.controlIn;
        connect sensing.dataOut to flightControl.sensorIn;
        connect sensing.dataOut to communication.dataIn;
        connect flightControl.payloadOut to payload.releaseCmd;

        // --- Behaviors ---
        state droneStates {
            state standby;
            state preFlightCheck;
            state flight {
                state cruising;
                state hovering;
                state maneuvering;
                state missionExecution {
                    state surveying;
                    state delivering;
                    state patrolling;
                }
            }
            state returnToBase;
            state emergencyLanding;

            transition initial to standby;
            transition standby to preFlightCheck when (communication.receivedCommand == "start");
            transition preFlightCheck to flight.cruising when (powerSystem.batteryLevel > batteryThreshold && !criticalFailure);
            transition preFlightCheck to emergencyLanding when (powerSystem.batteryLevel <= batteryThreshold || criticalFailure);

            transition flight.cruising to flight.hovering when (navigation.atDestination);
            transition flight.hovering to flight.maneuvering when (flightControl.adjusting);
            transition flight.maneuvering to flight.hovering when (!flightControl.adjusting);

            transition flight.hovering to flight.missionExecution.surveying when (missionType == "surveillance");
            transition flight.hovering to flight.missionExecution.delivering when (missionType == "delivery");
            transition flight.hovering to flight.missionExecution.patrolling when (missionType == "patrol");

            transition flight.missionExecution.surveying to flight.cruising when (sensing.surveyComplete);
            transition flight.missionExecution.delivering to flight.cruising when (payload.packageReleased);
            transition flight.missionExecution.patrolling to flight.cruising when (navigation.patrolComplete);

            transition flight to returnToBase when (powerSystem.batteryLevel <= batteryThreshold);
            transition flight to emergencyLanding when (criticalFailure);
            transition returnToBase to emergencyLanding when (criticalFailure);
            transition returnToBase to standby when (navigation.atBase);
            transition emergencyLanding to standby when (propulsion.landed);
        }
    }
}
