package QuadcopterDrone {
    import ScalarValues::*;
    
    value def Voltage :> Real;
    value def Current :> Real;
    value def Capacity :> Real;
    value def Acceleration :> Real;
    value def AngularVelocity :> Real;
    value def Pressure :> Real;
    value def MagneticField :> Real;
    value def Latitude :> Real;
    value def Longitude :> Real;
    value def Altitude :> Real;
    value def GroundSpeed :> Real;
    value def Throttle :> Real;
    
    item def IMUData {
        attr accelX : Acceleration;
        attr accelY : Acceleration;
        attr accelZ : Acceleration;
        attr gyroX : AngularVelocity;
        attr gyroY : AngularVelocity;
        attr gyroZ : AngularVelocity;
    }
    
    item def GPSData {
        attr lat : Latitude;
        attr lon : Longitude;
        attr alt : Altitude;
        attr groundSpeed : GroundSpeed;
    }
    
    item def BaroData {
        attr pressure : Pressure;
    }
    
    item def MagData {
        attr fieldX : MagneticField;
        attr fieldY : MagneticField;
        attr fieldZ : MagneticField;
    }
    
    item def BatteryData {
        attr voltage : Voltage;
        attr current : Current;
        attr remaining : Capacity;
    }
    
    item def RCInput {
        attr roll : Throttle;
        attr pitch : Throttle;
        attr yaw : Throttle;
        attr throttle : Throttle;
    }
    
    item def TelemetryData {
        attr position : GPSData;
        attr battery : BatteryData;
        attr mode : String;
    }
    
    item def MotorCommand {
        attr throttle : Throttle;
    }
    
    port def SensorOutPort { out item : IMUData; }
    port def GPSOutPort { out item : GPSData; }
    port def BaroOutPort { out item : BaroData; }
    port def MagOutPort { out item : MagData; }
    port def BatteryOutPort { out item : BatteryData; }
    port def RCOutPort { out item : RCInput; }
    port def TelemetryPort { out item : TelemetryData; in item : String; }
    port def MotorCmdPort { out item : MotorCommand; }
    port def PowerOutPort { out voltage : Voltage; out current : Current; }
    port def PowerInPort { in voltage : Voltage; in current : Current; }
    
    part def IMU {
        port sensorOut : SensorOutPort;
    }
    
    part def GPS {
        port gpsOut : GPSOutPort;
    }
    
    part def Barometer {
        port baroOut : BaroOutPort;
    }
    
    part def Magnetometer {
        port magOut : MagOutPort;
    }
    
    part def Battery {
        port powerOut : PowerOutPort;
        port monitorOut : BatteryOutPort;
        attr capacity : Capacity;
    }
    
    part def RCReceiver {
        port rcOut : RCOutPort;
    }
    
    part def TelemetryRadio {
        port telemetry : TelemetryPort;
    }
    
    part def ESC {
        port cmdIn : MotorCmdPort;
        port powerIn : PowerInPort;
        attr motorIndex : Integer;
    }
    
    part def BrushlessMotor {
        attr thrust : Real;
    }
    
    part def FlightController {
        port imuIn : SensorOutPort;
        port gpsIn : GPSOutPort;
        port baroIn : BaroOutPort;
        port magIn : MagOutPort;
        port batteryIn : BatteryOutPort;
        port rcIn : RCOutPort;
        port telemetry : TelemetryPort;
        port motorCmdOut : MotorCmdPort[4];
        port powerIn : PowerInPort;
        
        attribute currentMode : String;
        attribute isPowered : Boolean;
        attribute preFlightCheckPassed : Boolean;
        attribute armCommand : Boolean;
        attribute batteryLow : Boolean;
        attribute commLost : Boolean;
        
        state behavior {
            entry; then Off;
            
            state Off;
            
            transition off_to_init 
                first Off 
                to Initializing 
                when isPowered;
                
            state Initializing {
                entry; 
                // run self-diagnostics and calibrate sensors
            }
            
            transition init_to_disarmed 
                first Initializing 
                to Disarmed 
                when preFlightCheckPassed;
            
            state Disarmed {
                entry; 
                // wait for pre-flight safety checks
            }
            
            transition disarmed_to_armed 
                first Disarmed 
                to Armed 
                when armCommand;
                
            state Armed {
                entry; then Stabilize;
                
                state Stabilize;
                state AltitudeHold;
                state Loiter;
                state Auto;
                state RTL;
                
                transition stabilize_to_alt 
                    first Stabilize 
                    to AltitudeHold 
                    when currentMode == "AltitudeHold";
                    
                transition alt_to_loiter 
                    first AltitudeHold 
                    to Loiter 
                    when currentMode == "Loiter";
                    
                transition loiter_to_auto 
                    first Loiter 
                    to Auto 
                    when currentMode == "Auto";
                    
                transition auto_to_rtl 
                    first Auto 
                    to RTL 
                    when batteryLow || commLost;
                    
                transition stabilize_to_rtl 
                    first Stabilize 
                    to RTL 
                    when batteryLow || commLost;
                    
                transition alt_to_rtl 
                    first AltitudeHold 
                    to RTL 
                    when batteryLow || commLost;
                    
                transition loiter_to_rtl 
                    first Loiter 
                    to RTL 
                    when batteryLow || commLost;
            }
        }
    }
    
    part def QuadcopterFrame {
        attr armCount : Integer = 4;
    }
    
    part def QuadcopterDroneSystem {
        part frame : QuadcopterFrame;
        part flightController : FlightController;
        part imu : IMU;
        part gps : GPS;
        part baro : Barometer;
        part mag : Magnetometer;
        part battery : Battery;
        part rcReceiver : RCReceiver;
        part telemetryRadio : TelemetryRadio;
        
        part escs : ESC[4];
        part motors : BrushlessMotor[4];
        
        connection powerToFC connect battery.powerOut to flightController.powerIn;
        connection powerToESCs connect battery.powerOut to escs.powerIn;
        
        connection imuToFC connect imu.sensorOut to flightController.imuIn;
        connection gpsToFC connect gps.gpsOut to flightController.gpsIn;
        connection baroToFC connect baro.baroOut to flightController.baroIn;
        connection magToFC connect mag.magOut to flightController.magIn;
        connection batteryMonitorToFC connect battery.monitorOut to flightController.batteryIn;
        connection rcToFC connect rcReceiver.rcOut to flightController.rcIn;
        connection telemetryToFC connect telemetryRadio.telemetry to flightController.telemetry;
        
        connection cmdToESCs connect flightController.motorCmdOut to escs.cmdIn;
    }
    
    requirement def SafeFlightRequirement {
        doc /* The drone must only arm after passing pre-flight safety checks. */
    }
    
    requirement def FailsafeRequirement {
        doc /* The drone must enter RTL mode on low battery or loss of communication. */
    }
}
