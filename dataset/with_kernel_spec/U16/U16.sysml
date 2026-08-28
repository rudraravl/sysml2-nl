package ArduPilotQuadcopterSystem {
    value type Voltage { unit volt; }
    value type Current { unit ampere; }
    value type Capacity { unit milliampereHour; }
    value type Throttle;

    item def SensorData;
    item def RCCommand;
    item def TelemetryData;
    item def BatteryStatus;

    attribute def PowerOnSignal;
    attribute def DiagnosticsCompleteSignal;
    attribute def ArmSignal;
    attribute def DisarmSignal;
    attribute def StartFlightSignal;
    attribute def StopFlightSignal;
    attribute def LowBatterySignal;
    attribute def CommsLossSignal;
    attribute def SigStabilize;
    attribute def SigAltitudeHold;
    attribute def SigLoiter;
    attribute def SigAuto;
    attribute def SigRTL;

    enum def FlightMode {
        enum Stabilize;
        enum AltitudeHold;
        enum Loiter;
        enum Auto;
        enum ReturnToLaunch;
    }

    part def BrushlessMotor {
        port in motorCmdPort : Throttle;
    }

    part def ESC {
        port in cmdPort : Throttle;
        port in powerPort : Voltage;
        port out motorOutPort : Throttle;
    }

    part def QuadcopterFrame {
        part arms[4];
    }

    part def IMU {
        port out sensorPort : SensorData;
    }

    part def GPSModule {
        port out sensorPort : SensorData;
    }

    part def Barometer {
        port out sensorPort : SensorData;
    }

    part def Magnetometer {
        port out sensorPort : SensorData;
    }

    part def Battery {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute capacity : Capacity;
        port out powerPort : Voltage;
        port out statusPort : BatteryStatus;
    }

    part def RCReceiver {
        port out rcPort : RCCommand;
    }

    part def TelemetryRadio {
        port in telemInPort : TelemetryData;
        port out telemOutPort : TelemetryData;
    }

    part def FlightController {
        port in sensorDataPort : SensorData;
        port in rcInputPort : RCCommand;
        port in telemInputPort : TelemetryData;
        port out telemOutputPort : TelemetryData;
        port out escCmdPort1 : Throttle;
        port out escCmdPort2 : Throttle;
        port out escCmdPort3 : Throttle;
        port out escCmdPort4 : Throttle;
        port in batteryStatusPort : BatteryStatus;

        attribute currentMode : FlightMode;
        attribute checksPassed : Boolean = false;

        perform action performInitialization {
            first start;
            then action runDiagnostics;
            then action calibrateSensors;
            then done;
        }

        perform action controlLoop {
            first start;
            then action readSensors;
            then action fuseData;
            then action computeCommands;
            then action sendCommands;
            then done;
        }

        state controllerStates {
            entry; then off;
            state off;
            accept PowerOnSignal then initializing;
            state initializing {
                entry performInitialization;
            }
            accept DiagnosticsCompleteSignal then preFlight;
            state preFlight;
            accept ArmSignal if checksPassed then armed;
            state armed;
            accept DisarmSignal then preFlight;
            accept StartFlightSignal then flying;
            state flying {
                entry; then stabilize;
                do controlLoop;
                state stabilize;
                state altitudeHold;
                state loiter;
                state auto;
                state returnToLaunch;
                accept SigStabilize then stabilize;
                accept SigAltitudeHold then altitudeHold;
                accept SigLoiter then loiter;
                accept SigAuto then auto;
                accept SigRTL then returnToLaunch;
                accept LowBatterySignal then returnToLaunch;
                accept CommsLossSignal then returnToLaunch;
            }
            accept StopFlightSignal then armed;
        }
    }

    part def QuadcopterDrone {
        part frame : QuadcopterFrame;
        part motors[4] : BrushlessMotor;
        part escs[4] : ESC;
        part flightController : FlightController;
        part imu : IMU;
        part gps : GPSModule;
        part barometer : Barometer;
        part magnetometer : Magnetometer;
        part battery : Battery;
        part rcReceiver : RCReceiver;
        part telemetryRadio : TelemetryRadio;

        connect imu.sensorPort to flightController.sensorDataPort;
        connect gps.sensorPort to flightController.sensorDataPort;
        connect barometer.sensorPort to flightController.sensorDataPort;
        connect magnetometer.sensorPort to flightController.sensorDataPort;
        connect battery.statusPort to flightController.batteryStatusPort;
        connect battery.powerPort to escs[1].powerPort;
        connect battery.powerPort to escs[2].powerPort;
        connect battery.powerPort to escs[3].powerPort;
        connect battery.powerPort to escs[4].powerPort;
        connect rcReceiver.rcPort to flightController.rcInputPort;
        connect telemetryRadio.telemOutPort to flightController.telemInputPort;
        connect flightController.telemOutputPort to telemetryRadio.telemInPort;
        connect flightController.escCmdPort1 to escs[1].cmdPort;
        connect flightController.escCmdPort2 to escs[2].cmdPort;
        connect flightController.escCmdPort3 to escs[3].cmdPort;
        connect flightController.escCmdPort4 to escs[4].cmdPort;
        connect escs[1].motorOutPort to motors[1].motorCmdPort;
        connect escs[2].motorOutPort to motors[2].motorCmdPort;
        connect escs[3].motorOutPort to motors[3].motorCmdPort;
        connect escs[4].motorOutPort to motors[4].motorCmdPort;
    }

    part quadcopterDrone : QuadcopterDrone;

    requirement PreFlightSafetyRequirement {
        doc /* The drone shall only arm its motors after passing a series of pre-flight safety checks. */
    }
    requirement FailsafeRequirement {
        doc /* The drone shall automatically enter Return-to-Launch mode upon low battery or loss of communication. */
    }
    requirement ControlLoopRequirement {
        doc /* The flight controller shall run a continuous, high-speed control loop to fuse sensor data and compute motor commands. */
    }

    satisfy PreFlightSafetyRequirement by quadcopterDrone.flightController.controllerStates.preFlight;
    satisfy FailsafeRequirement by quadcopterDrone.flightController.controllerStates.flying.returnToLaunch;
    satisfy ControlLoopRequirement by quadcopterDrone.flightController.controlLoop;
}
