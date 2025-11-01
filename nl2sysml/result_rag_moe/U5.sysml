// Model a drone system with GPS navigation, a camera module, and an obstacle avoidance function.
package DroneSystem {
    import ISQ::*;
    import SI::*;
    import ScalarValues::*;

    //-------------------------------------------------
    // Library of Reusable Types and Definitions
    //-------------------------------------------------
    library package DroneLibrary {
        // Value and Item Types for Data Exchange
        enum def GPSStatusKind {
            noFix;
            acquiring;
            fix2D;
            fix3D;
        }

        enum def ObstacleProximityKind {
            clear;
            near;
            critical;
        }

        item def GPSPosition {
            attribute latitude : AngleValue;
            attribute longitude : AngleValue;
            attribute altitude : LengthValue;
        }

        item def ObstacleReport {
            attribute distance : LengthValue;
            attribute bearing : AngleValue;
            attribute proximity : ObstacleProximityKind;
        }

        item def VideoStream;
        
        item def MotorCommand {
            attribute throttle : RatioValue; // 0.0 to 1.0
        }

        // Port Definitions for Component Interfaces
        port def PowerInPort;
        port def PowerOutPort;
        
        port def GPSDataOutPort {
            out attribute position : GPSPosition;
            out attribute status : GPSStatusKind;
        }

        port def ObstacleDataOutPort {
            out attribute report : ObstacleReport;
        }

        port def VideoOutPort {
            out stream : VideoStream;
        }
        
        port def MotorCommandInPort {
            in command : MotorCommand;
        }

        // Flow Definitions for Data Transfer
        flow def PowerFlow {
            end port source : PowerOutPort;
            end port sink : PowerInPort;
        }
        
        flow def GPSDataFlow of GPSPosition from GPSDataOutPort to FlightControlUnit::gpsDataIn;
        flow def ObstacleDataFlow of ObstacleReport from ObstacleDataOutPort to FlightControlUnit::obstacleDataIn;
        flow def VideoDataFlow of VideoStream from VideoOutPort to FlightControlUnit::videoDataIn;
        flow def MotorCommandFlow of MotorCommand from FlightControlUnit::motorCommandOut to Motor::commandIn;
    }

    //-------------------------------------------------
    // Component Part Definitions
    //-------------------------------------------------
    private import DroneLibrary::*;

    part def GPSModule {
        attribute accuracy : LengthValue = 2.5[m];
        port powerIn : PowerInPort;
        port dataOut : GPSDataOutPort;

        perform action acquirePosition {
            out position : GPSPosition;
            out status : GPSStatusKind;
            first start;
            then action searchForSatellites;
            then action computePositionFix;
            then done;
        }

        state status {
            entry; then noFix;
            state noFix;
            accept PowerOn then acquiring;
            state acquiring;
            accept SatelliteLock then fix3D;
            state fix3D;
            accept SignalLost then acquiring;
        }
        attribute def PowerOn;
        attribute def SatelliteLock;
        attribute def SignalLost;
    }

    part def CameraModule {
        attribute resolution : String = "1920x1080";
        attribute frameRate : Real = 30.0;
        port powerIn : PowerInPort;
        port videoOut : VideoOutPort;

        perform action streamVideo {
            out stream : VideoStream;
            first start;
            then action initializeSensor;
            then action encodeStream;
            then done;
        }
    }

    part def ObstacleSensor {
        attribute detectionRange : LengthValue = 20.0[m];
        attribute fieldOfView : AngleValue = 60.0[deg];
        port powerIn : PowerInPort;
        port dataOut : ObstacleDataOutPort;

        perform action scanEnvironment {
            out report : ObstacleReport;
            first start;
            then action emitPulse;
            then action measureReturnTime;
            then action calculateDistanceAndBearing;
            then done;
        }
    }

    part def Battery {
        attribute capacity : ElectricChargeValue = 5000.0[mA*h];
        attribute nominalVoltage : ElectricPotentialValue = 14.8[V];
        attribute stateOfCharge : RatioValue = 1.0;
        port powerOut : PowerOutPort;
    }

    part def PowerManagementUnit {
        port batteryIn : PowerInPort;
        port avionicsPowerOut : PowerOutPort;
        port motorPowerOut[4] : PowerOutPort;
    }

    part def Motor {
        attribute maxThrust : ForceValue = 12.0[N];
        port powerIn : PowerInPort;
        port commandIn : MotorCommandInPort;
    }

    part def FlightControlUnit {
        port powerIn : PowerInPort;
        port gpsDataIn {
            in attribute position : GPSPosition;
        }
        port obstacleDataIn {
            in attribute report : ObstacleReport;
        }
        port videoDataIn {
            in stream : VideoStream;
        }
        port motorCommandOut[4] : MotorCommandInPort; // Mapped to motor inputs

        perform action executeMission[*] ordered {
            in waypoints : GPSPosition[1..*];
            first action takeoff;
            then loop for each waypoint in waypoints {
                perform action navigateToWaypoint {
                    in target = waypoint;
                    in current :>> position = gpsDataIn.position;
                }
            }
            then action land;
        }
        
        action navigateToWaypoint;
        action land;
        action takeoff;

        state flightMode {
            entry; then grounded;
            state grounded;
            accept TakeoffCmd then flying;
            state flying {
                entry; then navigating;
                state navigating;
                transition toAvoiding
                    when obstacleDataIn.report.proximity == ObstacleProximityKind::critical
                    first navigating then avoiding;
                state avoiding {
                    entry / perform action generateAvoidanceManeuver;
                }
                transition toNavigating
                    when obstacleDataIn.report.proximity == ObstacleProximityKind::clear
                    first avoiding then navigating;
            }
            accept LandCmd then grounded;
        }
        attribute def TakeoffCmd;
        attribute def LandCmd;
    }

    //-------------------------------------------------
    // System Requirements
    //-------------------------------------------------
    requirement def NavigationAccuracy {
        id = "R-NAV-01";
        text = "The drone shall determine its position with an accuracy of 3 meters or better.";
        assert constraint { that.satisfiedBy.accuracy <= 3.0[m] }
    }

    requirement def ObstacleDetection {
        id = "R-AVD-01";
        text = "The drone shall detect obstacles at a minimum range of 15 meters.";
        assert constraint { that.satisfiedBy.detectionRange >= 15.0[m] }
    }

    //-------------------------------------------------
    // Assembled Drone System
    //-------------------------------------------------
    part def SurveillanceDrone {
        part battery : Battery;
        part pmu : PowerManagementUnit;
        part motors[4] : Motor;
        part gps : GPSModule {
            satisfy NavigationAccuracy by self;
        }
        part camera : CameraModule;
        part obstacleSensor : ObstacleSensor {
            satisfy ObstacleDetection by self;
        }
        part fcu : FlightControlUnit;

        // Power Connections
        flow power_batt_pmu : PowerFlow from battery.powerOut to pmu.batteryIn;
        flow power_pmu_fcu : PowerFlow from pmu.avionicsPowerOut to fcu.powerIn;
        flow power_pmu_gps : PowerFlow from pmu.avionicsPowerOut to gps.powerIn;
        flow power_pmu_cam : PowerFlow from pmu.avionicsPowerOut to camera.powerIn;
        flow power_pmu_sens : PowerFlow from pmu.avionicsPowerOut to obstacleSensor.powerIn;
        flow power_pmu_motor1 : PowerFlow from pmu.motorPowerOut[1] to motors[1].powerIn;
        flow power_pmu_motor2 : PowerFlow from pmu.motorPowerOut[2] to motors[2].powerIn;
        flow power_pmu_motor3 : PowerFlow from pmu.motorPowerOut[3] to motors[3].powerIn;
        flow power_pmu_motor4 : PowerFlow from pmu.motorPowerOut[4] to motors[4].powerIn;

        // Data and Command Flows
        flow gps_to_fcu : GPSDataFlow from gps.dataOut to fcu.gpsDataIn;
        flow obstacle_to_fcu : ObstacleDataFlow from obstacleSensor.dataOut to fcu.obstacleDataIn;
        flow camera_to_fcu : VideoDataFlow from camera.videoOut to fcu.videoDataIn;
        
        // Note: SysMLv2 does not have a direct syntax for connecting an output port to an input port on the *same* part.
        // The intention here is to connect the FCU's motor command output ports to the motor's command input ports.
        // This is typically done with binding connectors or by refining the port definitions.
        // For clarity, we use explicit flows.
        flow fcu_to_motor1 : MotorCommandFlow from fcu.motorCommandOut[1] to motors[1].commandIn;
        flow fcu_to_motor2 : MotorCommandFlow from fcu.motorCommandOut[2] to motors[2].commandIn;
        flow fcu_to_motor3 : MotorCommandFlow from fcu.motorCommandOut[3] to motors[3].commandIn;
        flow fcu_to_motor4 : MotorCommandFlow from fcu.motorCommandOut[4] to motors[4].commandIn;
    }
}
