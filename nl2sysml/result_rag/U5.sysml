// Model a drone system with GPS navigation, a camera module, and an obstacle avoidance function.
package AdvancedSurveillanceDrone {
	import ISQ::Length;
	import ScalarValues::Real;
	import SI::{m, s, V, A, W};

	attribute def LatitudeValue :> Real;
	attribute def LongitudeValue :> Real;
	attribute def AltitudeValue :> Length;
	attribute def Voltage :> ISQ::ElectricPotential;
	attribute def Current :> ISQ::ElectricCurrent;
	attribute def Power :> ISQ::Power;

	item def GpsCoordinates {
		attribute latitude : LatitudeValue;
		attribute longitude : LongitudeValue;
		attribute altitude : AltitudeValue;
	}

	item def ObstacleDetection {
		attribute distance : Length;
		attribute isPresent : ScalarValues::Boolean;
	}

	item def VideoFeed;

	item def ElectricalPower {
		attribute voltage : Voltage;
		attribute current : Current;
	}

	port def GpsDataOut {
		out item location : GpsCoordinates;
	}

	port def ObstacleDataOut {
		out item detection : ObstacleDetection;
	}

	port def CameraDataOut {
		out item feed : VideoFeed;
	}

	port def FlightControllerIn {
		in item gpsLocation : GpsCoordinates;
		in item obstacleInfo : ObstacleDetection;
	}

	port def PowerOut {
		out item power : ElectricalPower;
	}

	port def PowerIn {
		in item power : ElectricalPower;
	}

	part def GpsReceiver {
		port dataPort : GpsDataOut;
		port powerInput : PowerIn;
		perform action acquirePosition {
			out item location : GpsCoordinates;
		}
	}

	part def ProximitySensor {
		port dataPort : ObstacleDataOut;
		port powerInput : PowerIn;
		perform action scanForObstacles {
			out item detection : ObstacleDetection;
		}
	}

	part def CameraGimbalAssembly {
		port dataPort : CameraDataOut;
		port powerInput : PowerIn;
		perform action streamVideo {
			out item feed : VideoFeed;
		}
	}

	part def FlightController {
		port sensorPort : FlightControllerIn;
		port powerInput : PowerIn;
		perform action navigateToWaypoint {
			in item target : GpsCoordinates;
			in item current : GpsCoordinates;
		}
		perform action executeAvoidanceManeuver {
			in item obstacle : ObstacleDetection;
		}
	}

	part def PowerDistributionUnit {
		port batteryIn : PowerIn;
		port gpsPower : PowerOut;
		port sensorPower : PowerOut;
		port cameraPower : PowerOut;
		port controllerPower : PowerOut;
	}

	part def Battery {
		port supply : PowerOut;
	}

	part def Drone {
		req Navigation {
			id = NAV01;
			text "The drone shall navigate to specified GPS waypoints.";
		}
		req Imaging {
			id = IMG01;
			text "The drone shall provide a live video feed from its camera.";
		}
		req Safety {
			id = SAF01;
			text "The drone shall automatically detect and avoid obstacles closer than 3 meters.";
		}

		part gps : GpsReceiver {
			satisfy Navigation by self;
		}
		part camera : CameraGimbalAssembly {
			satisfy Imaging by self;
		}
		part obstacleSensor : ProximitySensor {
			satisfy Safety by self;
		}
		part flightController : FlightController {
			satisfy Navigation by self;
			satisfy Safety by self;
		}
		part battery : Battery;
		part powerDistributor : PowerDistributionUnit;
		part propulsionSystem;
		part airframe;

		flow of GpsCoordinates from gps.dataPort to flightController.sensorPort;
		flow of ObstacleDetection from obstacleSensor.dataPort to flightController.sensorPort;

		flow of ElectricalPower from battery.supply to powerDistributor.batteryIn;
		flow of ElectricalPower from powerDistributor.gpsPower to gps.powerInput;
		flow of ElectricalPower from powerDistributor.sensorPower to obstacleSensor.powerInput;
		flow of ElectricalPower from powerDistributor.cameraPower to camera.powerInput;
		flow of ElectricalPower from powerDistributor.controllerPower to flightController.powerInput;

		action def PerformSurveillanceMission;
		perform action performMission : PerformSurveillanceMission ordered {
			action takeOff;
			action flyToTarget {
				in targetWaypoint : GpsCoordinates;
			}
			action surveyArea;
			action returnToBase;
			action land;
		}

		perform performMission.flyToTarget by flightController.navigateToWaypoint;
		perform performMission.surveyArea by camera.streamVideo;

		attribute def ArmSignal;
		attribute def DisarmSignal;
		attribute def LandSignal;

		state machine FlightBehavior {
			initial entry;
			then Idle;

			state Idle;
			accept ArmSignal then Armed;

			state Armed;
			accept DisarmSignal then Idle;
			transition Takeoff {
				first Armed;
				then Flying;
			}

			state Flying {
				accept LandSignal then Landing;
				transition DetectObstacle {
					first Flying;
					when obstacleSensor.dataPort.detection.isPresent and
						 obstacleSensor.dataPort.detection.distance < 3[m];
					then Avoiding;
				}
			}

			state Avoiding {
				perform executeAvoidanceManeuver by flightController;
				transition ObstacleCleared {
					first Avoiding;
					when not obstacleSensor.dataPort.detection.isPresent or
						 obstacleSensor.dataPort.detection.distance >= 3[m];
					then Flying;
				}
			}

			state Landing;
			transition Landed {
				first Landing;
				then Armed;
			}
		}
	}
}
}
