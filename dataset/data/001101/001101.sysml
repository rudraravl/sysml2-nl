package 'Inertial Reference Unit System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def AccelerationVector {
		attribute ax : AccelerationValue;
		attribute ay : AccelerationValue;
		attribute az : AccelerationValue;
	}

	attribute def AngularVelocityVector {
		attribute wx : AngularVelocityValue;
		attribute wy : AngularVelocityValue;
		attribute wz : AngularVelocityValue;
	}

	attribute def AttitudeAngles {
		attribute roll : PlaneAngleValue;
		attribute pitch : PlaneAngleValue;
		attribute yaw : PlaneAngleValue;
	}

	attribute def VelocityVector {
		attribute vx : SpeedValue;
		attribute vy : SpeedValue;
		attribute vz : SpeedValue;
	}

	attribute def PositionVector {
		attribute x : LengthValue;
		attribute y : LengthValue;
		attribute z : LengthValue;
	}

	item def AccelerometerReading {
		attribute acceleration : AccelerationVector;
		attribute timestamp : TimeValue;
		attribute temperature : TemperatureValue;
	}

	item def GyroscopeReading {
		attribute angularVelocity : AngularVelocityVector;
		attribute timestamp : TimeValue;
		attribute temperature : TemperatureValue;
	}

	item def NavigationState {
		attribute position : PositionVector;
		attribute velocity : VelocityVector;
		attribute attitude : AttitudeAngles;
		attribute timestamp : TimeValue;
		attribute quality : Real;
	}

	item def CalibrationData {
		attribute accelBias : AccelerationVector;
		attribute gyroBias : AngularVelocityVector;
		attribute accelScale : Real;
		attribute gyroScale : Real;
	}

	port def AccelerometerOutputPort {
		out item reading : AccelerometerReading;
	}

	port def GyroscopeOutputPort {
		out item reading : GyroscopeReading;
	}

	port def NavigationOutputPort {
		out item navState : NavigationState;
	}

	port def CalibrationPort {
		in item calibration : CalibrationData;
	}

	part def Accelerometer {
		attribute range : AccelerationValue;
		attribute bandwidth : FrequencyValue;
		attribute noiseDensity : AccelerationValue;

		port output : AccelerometerOutputPort;

		perform action measureAcceleration {
			out rawMeasurement : AccelerationVector;
			then action applyTemperatureCompensation {
				in rawData : AccelerationVector = rawMeasurement;
				in temperature : TemperatureValue;
				out compensatedData : AccelerationVector;
			}
			then action filterNoise {
				in inputData : AccelerationVector = applyTemperatureCompensation.compensatedData;
				out filteredData : AccelerationVector;
			}
			then action packageReading {
				in accelData : AccelerationVector = filterNoise.filteredData;
				out reading : AccelerometerReading;
			}
		}
	}

	part def Gyroscope {
		attribute range : AngularVelocityValue;
		attribute bandwidth : FrequencyValue;
		attribute noiseDensity : AngularVelocityValue;

		port output : GyroscopeOutputPort;

		perform action measureAngularVelocity {
			out rawMeasurement : AngularVelocityVector;
			then action compensateDrift {
				in rawData : AngularVelocityVector = rawMeasurement;
				in temperature : TemperatureValue;
				out compensatedData : AngularVelocityVector;
			}
			then action filterNoise {
				in inputData : AngularVelocityVector = compensateDrift.compensatedData;
				out filteredData : AngularVelocityVector;
			}
			then action packageReading {
				in gyroData : AngularVelocityVector = filterNoise.filteredData;
				out reading : GyroscopeReading;
			}
		}
	}

	part def InertialMeasurementUnit {
		part accelX : Accelerometer;
		part accelY : Accelerometer;
		part accelZ : Accelerometer;
		part gyroX : Gyroscope;
		part gyroY : Gyroscope;
		part gyroZ : Gyroscope;

		port accelOutputs : AccelerometerOutputPort[3];
		port gyroOutputs : GyroscopeOutputPort[3];

		connection accelXConn connect accelX.output to accelOutputs;
		connection accelYConn connect accelY.output to accelOutputs;
		connection accelZConn connect accelZ.output to accelOutputs;
		connection gyroXConn connect gyroX.output to gyroOutputs;
		connection gyroYConn connect gyroY.output to gyroOutputs;
		connection gyroZConn connect gyroZ.output to gyroOutputs;
	}

	part def NavigationComputer {
		in port accelInputs : ~AccelerometerOutputPort[3];
		in port gyroInputs : ~GyroscopeOutputPort[3];
		in port calibrationInput : CalibrationPort;
		out port navOutput : NavigationOutputPort;

		attribute updateRate : FrequencyValue;
		attribute currentPosition : PositionVector;
		attribute currentVelocity : VelocityVector;
		attribute currentAttitude : AttitudeAngles;

		perform action computeNavigationSolution {
			first start;
			then merge navigationCycle;

			action acquireSensorData {
				in accelReadings : AccelerometerReading[3];
				in gyroReadings : GyroscopeReading[3];
				out combinedAccel : AccelerationVector;
				out combinedGyro : AngularVelocityVector;
			}
			then navigationCycle;

			then action applyCalibration {
				in rawAccel : AccelerationVector = acquireSensorData.combinedAccel;
				in rawGyro : AngularVelocityVector = acquireSensorData.combinedGyro;
				in calibration : CalibrationData;
				out calibratedAccel : AccelerationVector;
				out calibratedGyro : AngularVelocityVector;
			}

			then action updateAttitudeEstimate {
				in gyroData : AngularVelocityVector = applyCalibration.calibratedGyro;
				in previousAttitude : AttitudeAngles = currentAttitude;
				in deltaTime : TimeValue;
				out newAttitude : AttitudeAngles;
			}

			then action transformAcceleration {
				in accelData : AccelerationVector = applyCalibration.calibratedAccel;
				in attitude : AttitudeAngles = updateAttitudeEstimate.newAttitude;
				out bodyFrameAccel : AccelerationVector;
			}

			then action updateVelocityEstimate {
				in accelData : AccelerationVector = transformAcceleration.bodyFrameAccel;
				in previousVelocity : VelocityVector = currentVelocity;
				in deltaTime : TimeValue;
				out newVelocity : VelocityVector;
			}

			then action updatePositionEstimate {
				in velocity : VelocityVector = updateVelocityEstimate.newVelocity;
				in previousPosition : PositionVector = currentPosition;
				in deltaTime : TimeValue;
				out newPosition : PositionVector;
			}

			then action assessQuality {
				in position : PositionVector = updatePositionEstimate.newPosition;
				in velocity : VelocityVector = updateVelocityEstimate.newVelocity;
				in attitude : AttitudeAngles = updateAttitudeEstimate.newAttitude;
				out qualityMetric : Real;
			}

			then action publishNavigationState {
				in position : PositionVector = updatePositionEstimate.newPosition;
				in velocity : VelocityVector = updateVelocityEstimate.newVelocity;
				in attitude : AttitudeAngles = updateAttitudeEstimate.newAttitude;
				in quality : Real = assessQuality.qualityMetric;
				out navState : NavigationState;
			}

			then assign currentPosition := updatePositionEstimate.newPosition;
			then assign currentVelocity := updateVelocityEstimate.newVelocity;
			then assign currentAttitude := updateAttitudeEstimate.newAttitude;
			then navigationCycle;
		}
	}

	part def InertialReferenceUnit {
		doc /* 
		An Inertial Reference Unit (IRU) is a self-contained navigation system that 
		continuously determines the position, velocity, and attitude of a vehicle or 
		platform in three-dimensional space. It operates by measuring linear accelerations 
		and angular velocities using precision accelerometers and gyroscopes, then 
		integrating these measurements over time to compute the complete navigation state 
		without requiring any external references such as GPS or radio signals.
		*/

		part imu : InertialMeasurementUnit;
		part computer : NavigationComputer;

		port navigationOutput : NavigationOutputPort;
		port calibrationInput : CalibrationPort;

		connection accelConnection connect imu.accelOutputs to computer.accelInputs;
		connection gyroConnection connect imu.gyroOutputs to computer.gyroInputs;
		connection navOutputConnection connect computer.navOutput to navigationOutput;
		connection calibrationConnection connect calibrationInput to computer.calibrationInput;

		perform action determineNavigationState {
			doc /* 
			The primary function of the IRU is to autonomously determine and continuously 
			update the complete navigation state by sensing inertial motion, processing 
			sensor measurements, and integrating them to provide accurate position, 
			velocity, and attitude information.
			*/

			first start;
			then merge continuousOperation;

			action senseInertialMotion {
				perform imu.accelX.measureAcceleration;
				perform imu.accelY.measureAcceleration;
				perform imu.accelZ.measureAcceleration;
				perform imu.gyroX.measureAngularVelocity;
				perform imu.gyroY.measureAngularVelocity;
				perform imu.gyroZ.measureAngularVelocity;
			}
			then continuousOperation;

			then action processNavigationData {
				perform computer.computeNavigationSolution;
			}

			then continuousOperation;
		}
	}

	requirement def PositionAccuracyRequirement {
		doc /* The IRU shall maintain position accuracy within specified limits. */
		attribute maxPositionError : LengthValue;
		attribute driftRate : SpeedValue;
	}

	requirement def AttitudeAccuracyRequirement {
		doc /* The IRU shall maintain attitude accuracy within specified angular limits. */
		attribute maxRollPitchError : PlaneAngleValue;
		attribute maxHeadingError : PlaneAngleValue;
	}

	requirement def UpdateRateRequirement {
		doc /* The IRU shall provide navigation updates at a minimum rate. */
		attribute minUpdateRate : FrequencyValue;
		require constraint {
			doc /* Navigation computer update rate shall meet or exceed minimum. */
		}
	}

	requirement def AutonomousOperationRequirement {
		doc /* The IRU shall operate independently without external references. */
		require constraint {
			doc /* System shall function using only internal inertial sensors. */
		}
	}

	requirement def ReliabilityRequirement {
		doc /* The IRU shall provide continuous reliable operation. */
		attribute meanTimeBetweenFailures : TimeValue;
		require constraint {
			doc /* System shall maintain specified MTBF under operational conditions. */
		}
	}

	requirement iruSystemRequirements {
		doc /* Top-level requirements for the Inertial Reference Unit system. */
		subject iruSystem : InertialReferenceUnit;

		require constraint posAccuracyConstraint {
			doc /* Position accuracy shall be maintained within limits. */
		}

		require constraint attAccuracyConstraint {
			doc /* Attitude accuracy shall be maintained within angular limits. */
		}

		require constraint updateRateConstraint {
			doc /* Update rate shall meet minimum frequency. */
		}

		require constraint autonomousOpConstraint {
			doc /* System shall operate autonomously. */
		}

		require constraint reliabilityConstraint {
			doc /* System shall meet reliability requirements. */
		}
	}

	part iruInstance : InertialReferenceUnit {
		:>> computer {
			:>> updateRate = 200.0 [Hz];
		}
		:>> imu {
			:>> accelX {
				:>> range = 10.0 [m/(s^2)];
				:>> bandwidth = 100.0 [Hz];
			}
			:>> gyroX {
				:>> range = 500.0 ['°'/s];
				:>> bandwidth = 100.0 [Hz];
			}
		}
	}
}
