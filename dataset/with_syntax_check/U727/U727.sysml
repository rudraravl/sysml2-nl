package 'Inertial Navigation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def Vector3D {
		attribute x : Real;
		attribute y : Real;
		attribute z : Real;
	}
	
	attribute def AccelerationVector :> Vector3D {
		attribute :>> x : Real;
		attribute :>> y : Real;
		attribute :>> z : Real;
		attribute xAccel : AccelerationValue;
		attribute yAccel : AccelerationValue;
		attribute zAccel : AccelerationValue;
	}
	
	attribute def AngularVelocityVector :> Vector3D {
		attribute :>> x : Real;
		attribute :>> y : Real;
		attribute :>> z : Real;
		attribute xRate : AngularVelocityValue;
		attribute yRate : AngularVelocityValue;
		attribute zRate : AngularVelocityValue;
	}
	
	attribute def PositionVector :> Vector3D {
		attribute :>> x : Real;
		attribute :>> y : Real;
		attribute :>> z : Real;
		attribute xPos : LengthValue;
		attribute yPos : LengthValue;
		attribute zPos : LengthValue;
	}
	
	attribute def VelocityVector :> Vector3D {
		attribute :>> x : Real;
		attribute :>> y : Real;
		attribute :>> z : Real;
		attribute xVel : SpeedValue;
		attribute yVel : SpeedValue;
		attribute zVel : SpeedValue;
	}
	
	attribute def OrientationAngles {
		attribute roll : Real;
		attribute pitch : Real;
		attribute yaw : Real;
		attribute rollAngle : ISQ::AngleValue;
		attribute pitchAngle : ISQ::AngleValue;
		attribute yawAngle : ISQ::AngleValue;
	}
	
	item def InertialMeasurement {
		attribute acceleration : AccelerationVector;
		attribute angularVelocity : AngularVelocityVector;
		attribute timestamp : TimeValue;
	}
	
	item def NavigationState {
		attribute position : PositionVector;
		attribute velocity : VelocityVector;
		attribute orientation : OrientationAngles;
		attribute timestamp : TimeValue;
	}
	
	item def CalibrationParameters {
		attribute accelerometerBias : AccelerationVector;
		attribute gyroscopeBias : AngularVelocityVector;
		attribute scaleFactor : Real;
		attribute alignmentMatrix : Real[9];
	}
	
	port def SensorDataPort {
		out item measurement : InertialMeasurement;
	}
	
	port def NavigationOutputPort {
		out item navState : NavigationState;
	}
	
	port def CalibrationInputPort {
		in item calibration : CalibrationParameters;
	}
	
	port def InitializationPort {
		in item initialState : NavigationState;
	}
	
	part def Accelerometer {
		attribute measurementRange : AccelerationValue;
		attribute resolution : AccelerationValue;
		attribute noiseLevel : AccelerationValue;
		
		port accelOutput {
			out item accelData : AccelerationVector;
		}
		
		action measureLinearAcceleration {
			out reading : AccelerationVector;
		}
	}
	
	part def Gyroscope {
		attribute measurementRange : AngularVelocityValue;
		attribute resolution : AngularVelocityValue;
		attribute driftRate : AngularVelocityValue;
		
		port gyroOutput {
			out item gyroData : AngularVelocityVector;
		}
		
		action measureAngularVelocity {
			out reading : AngularVelocityVector;
		}
	}
	
	part def InertialMeasurementUnit {
		doc /* 
			IMU containing three orthogonal accelerometers and three orthogonal gyroscopes
			to measure linear acceleration and angular velocity in all three axes.
		*/
		
		port imuDataPort : SensorDataPort;
		
		part accelerometerX : Accelerometer {
			doc /* X-axis accelerometer */
		}
		part accelerometerY : Accelerometer {
			doc /* Y-axis accelerometer */
		}
		part accelerometerZ : Accelerometer {
			doc /* Z-axis accelerometer */
		}
		
		part gyroscopeX : Gyroscope {
			doc /* X-axis gyroscope */
		}
		part gyroscopeY : Gyroscope {
			doc /* Y-axis gyroscope */
		}
		part gyroscopeZ : Gyroscope {
			doc /* Z-axis gyroscope */
		}
		
		action acquireSensorData {
			out imuData : InertialMeasurement;
			
			first start;
			then action readAccelerometers {
				out accelX : AccelerationValue;
				out accelY : AccelerationValue;
				out accelZ : AccelerationValue;
			}
			then action readGyroscopes {
				out gyroX : AngularVelocityValue;
				out gyroY : AngularVelocityValue;
				out gyroZ : AngularVelocityValue;
			}
			then action assembleMeasurement {
				in ax : AccelerationValue = readAccelerometers.accelX;
				in ay : AccelerationValue = readAccelerometers.accelY;
				in az : AccelerationValue = readAccelerometers.accelZ;
				in gx : AngularVelocityValue = readGyroscopes.gyroX;
				in gy : AngularVelocityValue = readGyroscopes.gyroY;
				in gz : AngularVelocityValue = readGyroscopes.gyroZ;
				out measurement : InertialMeasurement;
			}
			then done;
		}
	}
	
	part def NavigationProcessor {
		doc /* 
			Processes inertial measurements to compute navigation solution
			through integration and coordinate transformations.
		*/
		
		attribute updateRate : FrequencyValue;
		attribute currentState : NavigationState;
		
		port calibrationPort : CalibrationInputPort;
		port initializationPort : InitializationPort;
		port navigationOutputPort : NavigationOutputPort;
		
		action def CorrectSensorBias {
			in rawMeasurement : InertialMeasurement;
			in calibration : CalibrationParameters;
			out correctedMeasurement : InertialMeasurement;
		}
		
		action def UpdateAttitude {
			in angularVelocity : AngularVelocityVector;
			in currentOrientation : OrientationAngles;
			in deltaTime : TimeValue;
			out newOrientation : OrientationAngles;
		}
		
		action def TransformAcceleration {
			in bodyAcceleration : AccelerationVector;
			in orientation : OrientationAngles;
			out navigationAcceleration : AccelerationVector;
		}
		
		action def IntegrateVelocity {
			in acceleration : AccelerationVector;
			in currentVelocity : VelocityVector;
			in deltaTime : TimeValue;
			out newVelocity : VelocityVector;
		}
		
		action def IntegratePosition {
			in velocity : VelocityVector;
			in currentPosition : PositionVector;
			in deltaTime : TimeValue;
			out newPosition : PositionVector;
		}
		
		action computeNavigationSolution {
			in measurement : InertialMeasurement;
			in calibration : CalibrationParameters;
			in previousState : NavigationState;
			in deltaT : TimeValue;
			out navigationSolution : NavigationState;
			
			first start;
			then action correctBias : CorrectSensorBias {
				in rawMeasurement = measurement;
				in calibration = calibration;
				out correctedMeasurement;
			}
			then action updateOrientation : UpdateAttitude {
				in angularVelocity = correctBias.correctedMeasurement.angularVelocity;
				in currentOrientation = previousState.orientation;
				in deltaTime = deltaT;
				out newOrientation;
			}
			then action transformAccel : TransformAcceleration {
				in bodyAcceleration = correctBias.correctedMeasurement.acceleration;
				in orientation = updateOrientation.newOrientation;
				out navigationAcceleration;
			}
			then action computeVelocity : IntegrateVelocity {
				in acceleration = transformAccel.navigationAcceleration;
				in currentVelocity = previousState.velocity;
				in deltaTime = deltaT;
				out newVelocity;
			}
			then action computePosition : IntegratePosition {
				in velocity = computeVelocity.newVelocity;
				in currentPosition = previousState.position;
				in deltaTime = deltaT;
				out newPosition;
			}
			then action assembleState {
				in position : PositionVector = computePosition.newPosition;
				in velocity : VelocityVector = computeVelocity.newVelocity;
				in orientation : OrientationAngles = updateOrientation.newOrientation;
				out state : NavigationState;
			}
			then done;
		}
	}
	
	part def PowerManagement {
		attribute inputVoltage : Real;
		attribute outputVoltage : Real;
		attribute powerConsumption : PowerValue;
		attribute inputVolt : ISQ::VoltageValue;
		attribute outputVolt : ISQ::VoltageValue;
		
		port powerOutput {
			out item power : PowerValue;
		}
		
		action regulatePower {
			in demand : PowerValue;
			out supply : PowerValue;
		}
	}
	
	signal def SystemStart;
	signal def SystemStop;
	signal def CalibrationComplete;
	signal def InitializationComplete;
	
	state def INSOperationalModes {
		entry; then PowerOff;
		
		state PowerOff;
		state SelfTest;
		state Calibration;
		state Initialization;
		state Navigation;
		state Standby;
		
		transition powerOn 
			first PowerOff
			accept SystemStart
			then SelfTest;
			
		transition testComplete
			first SelfTest
			then Calibration;
			
		transition calibrationDone
			first Calibration
			accept CalibrationComplete
			then Initialization;
			
		transition initializationDone
			first Initialization
			accept InitializationComplete
			then Navigation;
			
		transition suspend
			first Navigation
			then Standby;
			
		transition resume
			first Standby
			then Navigation;
			
		transition shutdown
			first Navigation
			accept SystemStop
			then PowerOff;
	}
	
	part def InertialNavigationSystem {
		doc /* 
			An autonomous navigation system that determines position, velocity, and orientation
			by continuously measuring linear acceleration and angular velocity, then integrating
			these measurements over time. The system operates independently without external
			position references, making it suitable for applications where GPS or other external
			navigation aids are unavailable or unreliable.
		*/
		
		port navigationOutput : NavigationOutputPort;
		port calibrationInput : CalibrationInputPort;
		port initializationInput : InitializationPort;
		
		part imu : InertialMeasurementUnit {
			doc /* Provides continuous inertial measurements */
		}
		
		part processor : NavigationProcessor {
			doc /* Computes navigation solution from inertial measurements */
		}
		
		part power : PowerManagement {
			doc /* Manages power distribution to all subsystems */
		}
		
		connection imuToProcessor connect 
			imu.imuDataPort to processor;
			
		connection processorOutput connect 
			processor.navigationOutputPort to navigationOutput;
			
		connection calibrationConnection connect 
			calibrationInput to processor.calibrationPort;
			
		connection initializationConnection connect 
			initializationInput to processor.initializationPort;
		
		exhibit state insStateMachine : INSOperationalModes;
		
		action performInertialNavigation {
			in initialNavigationState : NavigationState;
			in systemCalibration : CalibrationParameters;
			out continuousNavigation : NavigationState[*] := ( );
			
			private attribute navState := initialNavigationState;
			private attribute samplePeriod : TimeValue;
			
			first start;
			then merge navigationCycle;
			then action acquireMeasurement {
				accept sensorData : InertialMeasurement;
			}
			then action processData : NavigationProcessor::computeNavigationSolution {
				in measurement = acquireMeasurement.sensorData;
				in calibration = systemCalibration;
				in previousState = navState;
				in deltaT = samplePeriod;
				out navigationSolution;
			}
			then action updateInternalState {
				assign navState := processData.navigationSolution;
			}
			then action recordSolution {
				assign continuousNavigation := 
					continuousNavigation->including(processData.navigationSolution);
			}
			then action outputNavigation {
				send processData.navigationSolution via navigationOutput;
			}
			then navigationCycle;
		}
	}
	
	requirement def AutonomousNavigationRequirement {
		doc /* 
			The system shall provide continuous autonomous navigation without 
			dependence on external position references.
		*/
		
		require constraint {
			doc /* Navigation solution computed solely from inertial measurements */
		}
	}
	
	requirement def AccuracyRequirement {
		doc /* The navigation system shall maintain specified accuracy bounds */
		
		attribute maxPositionError : LengthValue;
		attribute maxVelocityError : SpeedValue;
		attribute maxOrientationError : Real;
		attribute driftRate : SpeedValue;
		attribute maxOrientAngle : ISQ::AngleValue;
		
		require constraint {
			doc /* Position error growth rate shall not exceed specified drift */
		}
	}
	
	requirement def UpdateRateRequirement {
		doc /* The system shall provide navigation updates at minimum frequency */
		
		attribute minimumUpdateRate : FrequencyValue;
		
		require constraint {
			doc /* Navigation solution update rate meets minimum requirement */
		}
	}
	
	requirement def InitializationRequirement {
		doc /* The system shall accept initial position, velocity, and orientation */
		
		require constraint {
			doc /* Valid initial state provided before navigation begins */
		}
	}
	
	requirement def CalibrationRequirement {
		doc /* The system shall apply calibration to correct sensor errors */
		
		require constraint {
			doc /* Calibration parameters applied to all measurements */
		}
	}
	
	requirement <'INS-REQ-001'> primaryNavigationRequirement {
		doc /* 
			The Inertial Navigation System shall autonomously determine and continuously
			output the position, velocity, and orientation of the host platform by
			measuring linear acceleration and angular velocity with an inertial measurement
			unit and integrating these measurements over time using a navigation processor.
		*/
		
		subject insSystem : InertialNavigationSystem;
		
		assume constraint validInitialization {
			doc /* Initial navigation state is provided with known accuracy */
		}
		
		assume constraint validCalibration {
			doc /* Calibration parameters accurately characterize sensor errors */
		}
		
		assume constraint sensorFunctional {
			doc /* IMU sensors operate within specified performance parameters */
		}
		
		require autonomousOperation : AutonomousNavigationRequirement;
		
		require accuracy : AccuracyRequirement {
			maxPositionError = 1852.0 [m];
			maxVelocityError = 0.5 [m/s];
			maxOrientationError = 0.1;
			driftRate = 1.0 [m/s];
			maxOrientAngle = 0.1 [deg];
		}
		
		require updateRate : UpdateRateRequirement {
			minimumUpdateRate = 100.0 [Hz];
		}
		
		require initialization : InitializationRequirement;
		
		require calibration : CalibrationRequirement;
	}
	
	part insOperationalSystem : InertialNavigationSystem {
		:>> imu {
			:>> accelerometerX {
				:>> measurementRange = 100.0 [m/(s^2)];
				:>> resolution = 0.001 [m/(s^2)];
				:>> noiseLevel = 0.0001 [m/(s^2)];
			}
			:>> accelerometerY {
				:>> measurementRange = 100.0 [m/(s^2)];
				:>> resolution = 0.001 [m/(s^2)];
				:>> noiseLevel = 0.0001 [m/(s^2)];
			}
			:>> accelerometerZ {
				:>> measurementRange = 100.0 [m/(s^2)];
				:>> resolution = 0.001 [m/(s^2)];
				:>> noiseLevel = 0.0001 [m/(s^2)];
			}
			:>> gyroscopeX {
				:>> measurementRange = 6.28 [rad/s];
				:>> resolution = 0.0001 [rad/s];
				:>> driftRate = 0.00001 [rad/s];
			}
			:>> gyroscopeY {
				:>> measurementRange = 6.28 [rad/s];
				:>> resolution = 0.0001 [rad/s];
				:>> driftRate = 0.00001 [rad/s];
			}
			:>> gyroscopeZ {
				:>> measurementRange = 6.28 [rad/s];
				:>> resolution = 0.0001 [rad/s];
				:>> driftRate = 0.00001 [rad/s];
			}
		}
		
		:>> processor {
			:>> updateRate = 100.0 [Hz];
		}
		
		:>> power {
			:>> inputVoltage = 28.0;
			:>> outputVoltage = 5.0;
			:>> powerConsumption = 15.0 [W];
			:>> inputVolt = 28.0 [V];
			:>> outputVolt = 5.0 [V];
		}
		
		satisfy primaryNavigationRequirement by insOperationalSystem;
	}
}
