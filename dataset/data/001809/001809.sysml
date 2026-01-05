package MagneticFieldSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def MagneticFluxDensityValue :> ISQ::MagneticFluxDensityValue;
	attribute def MagneticFieldStrengthValue :> ISQ::MagneticFieldStrengthValue;
	attribute def ElectricCurrentValue :> ISQ::ElectricCurrentValue;
	attribute def VoltageValue :> ISQ::VoltageValue;
	
	item def FieldVector {
		attribute magnitude : MagneticFluxDensityValue;
		attribute direction : Real[3];
		attribute position : ISQ::LengthValue[3];
	}
	
	item def SensorReading {
		attribute fieldStrength : MagneticFluxDensityValue;
		attribute timestamp : ISQ::TimeValue;
		attribute sensorId : String;
	}
	
	item def ControlCommand {
		attribute targetCurrent : ElectricCurrentValue;
		attribute rampRate : Real;
	}
	
	port def PowerInputPort {
		in attribute voltage : VoltageValue;
		in attribute current : ElectricCurrentValue;
	}
	
	port def FieldOutputPort {
		out item fieldData : FieldVector;
	}
	
	port def SensorDataPort {
		out item reading : SensorReading;
	}
	
	port def ControlInputPort {
		in item command : ControlCommand;
	}
	
	part def PowerSupply {
		port powerOut : PowerInputPort;
		attribute maxVoltage : VoltageValue;
		attribute maxCurrent : ElectricCurrentValue;
		attribute outputVoltage : VoltageValue;
		attribute outputCurrent : ElectricCurrentValue;
	}
	
	part def Electromagnet {
		port powerIn : PowerInputPort;
		port fieldOut : FieldOutputPort;
		port controlIn : ControlInputPort;
		
		attribute coilTurns : Integer;
		attribute corePermeability : Real;
		attribute operatingCurrent : ElectricCurrentValue;
		attribute generatedField : MagneticFluxDensityValue;
		attribute targetCurrent : ElectricCurrentValue;
		
		action def RampUpCurrent;
		action def MonitorCurrent;
		action def MaintainField;
		action def RegulateCurrent;
		action def ModifyCurrent;
		action def RampDownCurrent;
		
		state electromagnet {
			entry; then off;
			
			state off;
			state energizing;
			state stable;
			state adjusting;
			state deenergizing;
			
			transition off_to_energizing
				first off
				then energizing;
			
			transition energizing_to_stable
				first energizing
				then stable;
			
			transition stable_to_adjusting
				first stable
				then adjusting;
			
			transition adjusting_to_stable
				first adjusting
				then stable;
			
			transition stable_to_deenergizing
				first stable
				then deenergizing;
			
			transition deenergizing_to_off
				first deenergizing
				then off;
		}
		
		perform action generateMagneticField {
			in inputCurrent : ElectricCurrentValue;
			out outputField : FieldVector;
			
			first start;
			then action calculateFieldStrength {
				in current : ElectricCurrentValue = inputCurrent;
				in turns : Integer = coilTurns;
				in permeability : Real = corePermeability;
				out fieldMagnitude : MagneticFluxDensityValue;
			}
			then action constructFieldVector {
				in magnitude : MagneticFluxDensityValue = calculateFieldStrength.fieldMagnitude;
				out field : FieldVector;
			}
			then action emitField {
				in field : FieldVector = constructFieldVector.field;
			}
			then done;
		}
	}
	
	part def FieldSensor {
		port fieldIn : FieldOutputPort;
		port dataOut : SensorDataPort;
		
		attribute sensitivity : Real;
		attribute measurementRange : MagneticFluxDensityValue;
		attribute accuracy : Real;
		attribute currentReading : MagneticFluxDensityValue;
		
		perform action measureField {
			in inputField : FieldVector;
			out measurement : SensorReading;
			
			first start;
			then action sampleField {
				in field : FieldVector = inputField;
				out rawValue : Real;
			}
			then action applyCalibration {
				in raw : Real = sampleField.rawValue;
				in calibrationFactor : Real = sensitivity;
				out calibrated : MagneticFluxDensityValue;
			}
			then action createReading {
				in fieldValue : MagneticFluxDensityValue = applyCalibration.calibrated;
				out reading : SensorReading;
			}
			then action transmitData {
				in data : SensorReading = createReading.reading;
			}
			then done;
		}
	}
	
	part def FieldController {
		port sensorInput : SensorDataPort;
		port commandOutput : ControlInputPort;
		
		attribute targetFieldStrength : MagneticFluxDensityValue;
		attribute tolerance : Real;
		attribute proportionalGain : Real;
		attribute integralGain : Real;
		attribute errorAccumulator : Real;
		attribute fieldError : Real;
		
		action def LoadParameters;
		action def ReadSensor;
		action def EvaluateError;
		action def ComputeCorrection;
		action def IssueCommand;
		action def MaintainSetpoint;
		
		state controller {
			entry; then initializing;
			
			state initializing;
			state monitoring;
			state correcting;
			state holding;
			
			transition init_to_monitoring
				first initializing
				then monitoring;
			
			transition monitoring_to_correcting
				first monitoring
				then correcting;
			
			transition monitoring_to_holding
				first monitoring
				then holding;
			
			transition correcting_to_monitoring
				first correcting
				then monitoring;
			
			transition holding_to_monitoring
				first holding
				then monitoring;
		}
		
		perform action regulateField {
			in targetField : MagneticFluxDensityValue;
			in currentMeasurement : SensorReading;
			out controlCommand : ControlCommand;
			
			first start;
			then merge controlLoop;
			then action computeError {
				in target : MagneticFluxDensityValue = targetField;
				in actual : MagneticFluxDensityValue = currentMeasurement.fieldStrength;
				out error : Real;
			}
			then action updateIntegral {
				in error : Real = computeError.error;
				in previousIntegral : Real = errorAccumulator;
				out newIntegral : Real;
			}
			then assign errorAccumulator := updateIntegral.newIntegral;
			then decide;
				if computeError.error > tolerance then correct;
				if computeError.error <= tolerance then hold;
			
			action correct {
				in errorValue : Real = computeError.error;
				in integralValue : Real = errorAccumulator;
				in kp : Real = proportionalGain;
				in ki : Real = integralGain;
				out correction : ElectricCurrentValue;
			}
			then action issueCorrection {
				in currentAdjustment : ElectricCurrentValue = correct.correction;
				out command : ControlCommand;
			}
			then controlLoop;
			
			action hold {
				out steadyCommand : ControlCommand;
			}
			then done;
		}
	}
	
	part def ShieldingEnclosure {
		attribute material : String;
		attribute thickness : ISQ::LengthValue;
		attribute shieldingFactor : Real;
		
		perform action attenuateExternalField {
			in externalField : FieldVector;
			out shieldedField : FieldVector;
			
			first start;
			then action calculateAttenuation {
				in inputField : FieldVector = externalField;
				in factor : Real = shieldingFactor;
				out attenuated : FieldVector;
			}
			then done;
		}
	}
	
	part magneticFieldSystem {
		doc /* 
		 * A precision magnetic field system that generates, measures, and actively controls
		 * a stable magnetic field for applications such as scientific research, medical imaging,
		 * materials testing, or particle beam steering. The system maintains field strength
		 * within tight tolerances through continuous feedback control.
		 */
		
		part powerSupply : PowerSupply;
		part mainMagnet : Electromagnet;
		part fieldSensor : FieldSensor;
		part controller : FieldController;
		part shielding : ShieldingEnclosure;
		
		connection powerConnection connect 
			powerSupply.powerOut to mainMagnet.powerIn;
		
		connection fieldMeasurement connect 
			mainMagnet.fieldOut to fieldSensor.fieldIn;
		
		connection sensorFeedback connect 
			fieldSensor.dataOut to controller.sensorInput;
		
		connection controlFeedback connect 
			controller.commandOutput to mainMagnet.controlIn;
		
		perform action operateMagneticFieldSystem {
			doc /* 
			 * Primary function: Generate and maintain a precise, stable magnetic field
			 * through continuous monitoring and active feedback control.
			 */
			
			first start;
			then action initializeSystem;
			then merge operationalLoop;
			then action monitorAndControl;
			then action evaluateStability {
				out isStable : Boolean;
			}
			then decide;
				if evaluateStability.isStable then operationalLoop;
			
			action correctField;
			then operationalLoop;
		}
	}
	
	requirement def FieldStabilityRequirement {
		doc /* The magnetic field strength shall remain within specified tolerance of target value during operation. */
		
		subject magneticFieldSystem;
		attribute maxDeviation : Real;
	}
	
	requirement def FieldUniformityRequirement {
		doc /* The magnetic field shall exhibit spatial uniformity across the working volume. */
		
		subject magneticFieldSystem;
		attribute maxVariation : Real;
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The system shall achieve target field strength within specified settling time. */
		
		subject magneticFieldSystem;
		attribute maxSettlingTime : ISQ::TimeValue;
	}
	
	requirement def SafetyRequirement {
		doc /* The system shall safely de-energize in case of fault conditions. */
		
		subject magneticFieldSystem;
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the magnetic field system. */
		
		require stabilityReq : FieldStabilityRequirement;
		require uniformityReq : FieldUniformityRequirement;
		require responseReq : ResponseTimeRequirement;
		require safetyReq : SafetyRequirement;
	}
}
