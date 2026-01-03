package GyroscopeNavigationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AngularRateVector {
		attribute rollRate : AngularVelocityValue;
		attribute pitchRate : AngularVelocityValue;
		attribute yawRate : AngularVelocityValue;
	}
	
	attribute def AttitudeAngles {
		attribute roll : PlaneAngleValue;
		attribute pitch : PlaneAngleValue;
		attribute yaw : PlaneAngleValue;
	}
	
	attribute def BiasCorrection {
		attribute rollBias : AngularVelocityValue;
		attribute pitchBias : AngularVelocityValue;
		attribute yawBias : AngularVelocityValue;
	}
	
	enum def GyroModeEnum {
		enum initialization;
		enum calibration;
		enum operational;
		enum error;
	}
	
	attribute def GyroStatusData {
		attribute mode : GyroModeEnum;
		attribute temperature : TemperatureValue;
		attribute isReady : Boolean;
	}
	
	attribute def CalibrationCmd;
	attribute def StartCmd;
	attribute def StopCmd;
	
	port def GyroOutputPort {
		out angularRates : AngularRateVector;
		out attitude : AttitudeAngles;
		out status : GyroStatusData;
	}
	
	port def PowerInputPort {
		in voltage : ElectricPotentialValue;
		in current : ElectricCurrentValue;
	}
	
	port def CommandPort {
		in startCommand : StartCmd;
		in stopCommand : StopCmd;
		in calibrateCommand : CalibrationCmd;
	}
	
	part def GyroSensingElement {
		attribute resonanceFrequency : FrequencyValue;
		attribute sensitivity : Real;
		perform action detectRotation : DetectRotation;
	}
	
	part def SignalConditioner {
		perform action amplifySignal : AmplifySignal;
		perform action filterNoise : FilterNoise;
	}
	
	part def DigitalProcessor {
		attribute samplingRate : FrequencyValue;
		perform action computeAttitude : ComputeAttitude;
	}
	
	part def CalibrationModule {
		attribute biasData : BiasCorrection;
		perform action determineBias : DetermineBias;
	}
	
	part def Gyroscope {
		attribute mass : MassValue;
		attribute operatingTempMin : TemperatureValue;
		attribute operatingTempMax : TemperatureValue;
		attribute maxAngularRate : AngularVelocityValue;
		
		port powerIn : PowerInputPort;
		port dataOut : GyroOutputPort;
		port commandIn : CommandPort;
		
		part sensingElement : GyroSensingElement {
			attribute :>> resonanceFrequency = 10000.0[Hz];
			attribute :>> sensitivity = 0.005;
		}
		
		part conditioner : SignalConditioner;
		
		part processor : DigitalProcessor {
			attribute :>> samplingRate = 1000.0[Hz];
		}
		
		part calibrator : CalibrationModule;
		
		perform action measureAndTrackOrientation : MeasureAndTrackOrientation;
	}
	
	action def DetectRotation {
		in physicalRotation : AngularRateVector;
		out rawSignalX : Real;
		out rawSignalY : Real;
		out rawSignalZ : Real;
	}
	
	action def AmplifySignal {
		in rawSignalX : Real;
		in rawSignalY : Real;
		in rawSignalZ : Real;
		out amplifiedX : Real;
		out amplifiedY : Real;
		out amplifiedZ : Real;
	}
	
	action def FilterNoise {
		in amplifiedX : Real;
		in amplifiedY : Real;
		in amplifiedZ : Real;
		out filteredX : Real;
		out filteredY : Real;
		out filteredZ : Real;
	}
	
	action def DetermineBias {
		in sampleCount : Integer;
		out biasCorrection : BiasCorrection;
	}
	
	action def ApplyBiasCorrection {
		in rawRates : AngularRateVector;
		in bias : BiasCorrection;
		out correctedRates : AngularRateVector;
	}
	
	action def IntegrateAngularRates {
		in angularRates : AngularRateVector;
		in deltaTime : DurationValue;
		in previousAttitude : AttitudeAngles;
		out updatedAttitude : AttitudeAngles;
	}
	
	action def ComputeAttitude {
		in correctedRates : AngularRateVector;
		in integrationInterval : DurationValue;
		in priorAttitude : AttitudeAngles;
		out currentAttitude : AttitudeAngles;
	}
	
	action def MeasureAndTrackOrientation {
		in powerVoltage : ElectricPotentialValue;
		out outputAngularRates : AngularRateVector;
		out outputAttitude : AttitudeAngles;
		out outputStatus : GyroStatusData;
		
		private attribute currentAttitude : AttitudeAngles;
		private attribute currentRates : AngularRateVector;
		private attribute systemStatus : GyroStatusData;
		private attribute biasData : BiasCorrection;
		private attribute sampleInterval : DurationValue;
		
		first start;
		
		then action initialize {
			then assign systemStatus := GyroStatusData {
				mode = GyroModeEnum::initialization;
				temperature = 298.15[K];
				isReady = false;
			}
			then assign currentAttitude := AttitudeAngles {
				roll = 0.0[rad];
				pitch = 0.0[rad];
				yaw = 0.0[rad];
			}
			then assign sampleInterval := 0.001[s];
		}
		
		then accept calibrateCmd : CalibrationCmd;
		
		then action calibrate : DetermineBias {
			in sampleCount = 1000;
			out biasCorrection;
		}
		
		then assign biasData := calibrate.biasCorrection;
		
		then action updateCalibrationStatus {
			then assign systemStatus := GyroStatusData {
				mode = GyroModeEnum::calibration;
				temperature = 298.15[K];
				isReady = false;
			}
		}
		
		then accept startCmd : StartCmd;
		
		then action updateOperationalStatus {
			then assign systemStatus := GyroStatusData {
				mode = GyroModeEnum::operational;
				temperature = 298.15[K];
				isReady = true;
			}
		}
		
		then merge continuousTracking;
		
		then action trackingLoop {
			loop {
				action detectRot : DetectRotation {
					in physicalRotation = currentRates;
					out rawSignalX;
					out rawSignalY;
					out rawSignalZ;
				}
				
				then action amplify : AmplifySignal {
					in rawSignalX = detectRot.rawSignalX;
					in rawSignalY = detectRot.rawSignalY;
					in rawSignalZ = detectRot.rawSignalZ;
					out amplifiedX;
					out amplifiedY;
					out amplifiedZ;
				}
				
				then action filter : FilterNoise {
					in amplifiedX = amplify.amplifiedX;
					in amplifiedY = amplify.amplifiedY;
					in amplifiedZ = amplify.amplifiedZ;
					out filteredX;
					out filteredY;
					out filteredZ;
				}
				
				then action convertToRates {
					then assign currentRates := AngularRateVector {
						rollRate = filter.filteredX[rad/s];
						pitchRate = filter.filteredY[rad/s];
						yawRate = filter.filteredZ[rad/s];
					}
				}
				
				then action correctBias : ApplyBiasCorrection {
					in rawRates = currentRates;
					in bias = biasData;
					out correctedRates;
				}
				
				then action integrate : IntegrateAngularRates {
					in angularRates = correctBias.correctedRates;
					in deltaTime = sampleInterval;
					in previousAttitude = currentAttitude;
					out updatedAttitude;
				}
				
				then assign currentAttitude := integrate.updatedAttitude;
				then assign outputAngularRates := correctBias.correctedRates;
				then assign outputAttitude := currentAttitude;
				then assign outputStatus := systemStatus;
				
				then continuousTracking;
			}
		}
		
		then accept stopCmd : StopCmd;
		
		then action updateStopStatus {
			then assign systemStatus := GyroStatusData {
				mode = GyroModeEnum::initialization;
				temperature = 298.15[K];
				isReady = false;
			}
		}
		
		then done;
	}
	
	part gyroscopeNavigationSystem {
		part gyro : Gyroscope {
			attribute :>> mass = 0.08[kg];
			attribute :>> operatingTempMin = 233.15[K];
			attribute :>> operatingTempMax = 358.15[K];
			attribute :>> maxAngularRate = 2000.0[deg/s];
			
			perform measureAndTrackOrientation {
				in powerVoltage;
				out outputAngularRates;
				out outputAttitude;
				out outputStatus;
			}
		}
		
		part powerSource {
			attribute supplyVoltage : ElectricPotentialValue = 5.0[V];
			attribute supplyCurrent : ElectricCurrentValue = 0.05[A];
		}
		
		part navigationComputer {
			in attitudeData : AttitudeAngles;
			in rateData : AngularRateVector;
			out navigationSolution;
		}
		
		connection powerLink connect powerSource to gyro.powerIn;
		connection dataLink connect gyro.dataOut to navigationComputer;
	}
	
	requirement <'GYR-REQ-001'> primaryNavigationFunction {
		doc /* The gyroscope system shall continuously measure the angular rotation 
		       rates about three orthogonal axes and integrate these rates over time 
		       to determine and track the orientation (roll, pitch, yaw) of the 
		       platform in three-dimensional space, providing real-time attitude 
		       information for navigation and stabilization purposes. */
		
		subject gyroscopeNavigationSystem;
		
		require constraint measurementAccuracy {
			doc /* Angular rate measurement accuracy shall be within 0.01 deg/s 
			       and attitude determination accuracy shall be within 0.1 degrees. */
		}
		
		require constraint updateRate {
			doc /* The system shall provide attitude updates at a minimum rate 
			       of 100 Hz to support dynamic platform control. */
		}
		
		require constraint calibrationCapability {
			doc /* The gyroscope shall perform bias calibration on command to 
			       compensate for drift and maintain long-term accuracy. */
		}
	}
	
	requirement <'GYR-REQ-002'> operationalReliability {
		doc /* The gyroscope system shall operate reliably under specified 
		       environmental and operational conditions. */
		
		assume constraint environmentalConditions {
			doc /* Operating temperature range: -40°C to +85°C. 
			       Maximum angular rate: 2000 deg/s. */
		}
		
		require constraint continuousOperation {
			doc /* The system shall operate continuously for at least 10,000 hours 
			       without degradation in performance. */
		}
	}
	
	requirement <'GYR-REQ-003'> powerEfficiency {
		doc /* The gyroscope system shall minimize power consumption to enable 
		       integration into portable and battery-powered platforms. */
		
		require constraint maxPowerDraw {
			doc /* Maximum power consumption shall not exceed 250 mW during 
			       continuous operational mode. */
		}
		
		assume constraint powerSupply {
			doc /* Input voltage shall be 5.0V ± 0.5V DC with current capacity 
			       of at least 50 mA. */
		}
	}
}
