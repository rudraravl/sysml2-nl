package 'Bourdon Gauge System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import NumericalFunctions::*;
	
	attribute def CalibrationFactor :> Real;
	attribute def ErrorTolerance :> Real;
	
	port def PressurePort {
		attribute pressure : PressureValue;
	}
	
	port def MechanicalPort {
		attribute displacement : LengthValue;
	}
	
	port def RotationalPort {
		attribute angle : Real;
	}
	
	part def BourdonTube {
		doc /* Curved elastic tube that deforms under pressure */
		attribute material : String;
		attribute crossSection : String;
		attribute curvatureRadius : LengthValue;
		port pressureInput : PressurePort;
		port mechanicalOutput : MechanicalPort;
	}
	
	part def LinkageMechanism {
		doc /* Converts linear displacement to rotational motion */
		attribute leverRatio : Real;
		attribute gearRatio : Real;
		port mechanicalInput : MechanicalPort;
		port rotationalOutput : RotationalPort;
	}
	
	part def PointerAssembly {
		doc /* Indicates pressure reading on dial */
		attribute pointerLength : LengthValue;
		attribute currentPosition : Real;
		port rotationalInput : RotationalPort;
	}
	
	part def DialFace {
		doc /* Calibrated scale for pressure reading */
		attribute minimumPressure : PressureValue;
		attribute maximumPressure : PressureValue;
		attribute numberOfDivisions : Integer;
		attribute pressureUnits : String;
	}
	
	part def EnclosureHousing {
		doc /* Protective casing and mounting interface */
		attribute housingMaterial : String;
		attribute connectionType : String;
		attribute windowMaterial : String;
		port processConnection : PressurePort;
	}
	
	action def DeformTube {
		in inputPressure : PressureValue;
		in tubeElasticity : Real;
		out tipDisplacement : LengthValue;
	}
	
	action def ConvertToRotation {
		in linearMotion : LengthValue;
		in mechanicalAdvantage : Real;
		out angularDisplacement : Real;
	}
	
	action def DisplayReading {
		in pointerPosition : Real;
		in scaleCalibration : CalibrationFactor;
		out pressureIndication : PressureValue;
	}
	
	action def MeasureFluidPressure {
		in appliedPressure : PressureValue;
		in tubeProperties : Real;
		in linkageRatio : Real;
		in calibration : CalibrationFactor;
		out indicatedPressure : PressureValue;
		
		first start;
		then action deform : DeformTube {
			in inputPressure = appliedPressure;
			in tubeElasticity = tubeProperties;
			out tipDisplacement : LengthValue;
		}
		flow deform.tipDisplacement to convert.linearMotion;
		then action convert : ConvertToRotation {
			in linearMotion : LengthValue;
			in mechanicalAdvantage = linkageRatio;
			out angularDisplacement : Real;
		}
		flow convert.angularDisplacement to display.pointerPosition;
		then action display : DisplayReading {
			in pointerPosition : Real;
			in scaleCalibration = calibration;
			out pressureIndication : PressureValue;
		}
		then assign indicatedPressure := display.pressureIndication;
		then done;
	}
	
	attribute def PressureAppliedSignal;
	attribute def PressureFluctuationSignal;
	attribute def PressureReleasedSignal;
	
	state def GaugeOperationalStates {
		in attribute currentPressure : PressureValue;
		in attribute stabilized : Boolean;
		
		entry; then standby;
		
		state standby {
			doc /* Gauge at ambient pressure, pointer at zero */
		}
		
		transition standby_to_active
			first standby
			accept pressureApplied : PressureAppliedSignal
			then active;
		
		state active {
			doc /* Gauge responding to applied pressure */
		}
		
		transition active_to_stable
			first active
			if stabilized
			then stable;
		
		state stable {
			doc /* Pressure reading steady */
		}
		
		transition stable_to_active
			first stable
			accept pressureFluctuation : PressureFluctuationSignal
			then active;
		
		transition active_to_standby
			first active
			accept pressureReleased : PressureReleasedSignal
			then standby;
		
		transition stable_to_standby
			first stable
			accept pressureReleased : PressureReleasedSignal
			then standby;
	}
	
	part def BourdonGauge {
		doc /* Complete Bourdon gauge assembly */
		
		attribute actualPressure : PressureValue;
		attribute indicatedPressure : PressureValue;
		attribute responseTime : TimeValue;
		attribute operationalMode : String;
		attribute systemPressure : PressureValue;
		attribute pressureStabilized : Boolean;
		
		part tube : BourdonTube;
		part linkage : LinkageMechanism;
		part pointer : PointerAssembly;
		part dial : DialFace;
		part housing : EnclosureHousing;
	}
	
	requirement def <'REQ-FUNC-001'> PrimaryFunctionRequirement {
		doc /* 
		The Bourdon gauge shall convert fluid pressure into a mechanical 
		displacement that produces a visual indication on a calibrated dial.
		*/
		
		subject gauge : BourdonGauge;
		
		require constraint functionalOperation {
			doc /* System shall provide continuous pressure indication */
			gauge.operationalMode == "continuous measurement"
		}
	}
	
	requirement def <'REQ-ACC-001'> MeasurementAccuracyRequirement {
		doc /* 
		The Bourdon gauge shall indicate pressure within ±1.5% of full scale 
		across the entire operating range.
		*/
		
		subject gauge : BourdonGauge;
		
		require constraint accuracyTolerance {
			doc /* Reading error within specified tolerance */
			abs(gauge.indicatedPressure - gauge.actualPressure) <= 
				0.015 * gauge.dial.maximumPressure
		}
	}
	
	requirement def <'REQ-RANGE-001'> OperatingRangeRequirement {
		doc /* 
		The Bourdon gauge shall measure pressures from 0 to 10 MPa 
		(0 to 1450 psi).
		*/
		
		subject gauge : BourdonGauge;
		
		require constraint pressureRange {
			gauge.dial.minimumPressure == 0.0 [SI::Pa] and
			gauge.dial.maximumPressure == 10000000.0 [SI::Pa]
		}
	}
	
	requirement def <'REQ-RESP-001'> ResponseTimeRequirement {
		doc /* 
		The Bourdon gauge shall respond to 90% of a step pressure change 
		within 0.5 seconds.
		*/
		
		subject gauge : BourdonGauge;
		
		require constraint responseSpeed {
			gauge.responseTime <= 0.5 [SI::s]
		}
	}
	
	requirement def <'REQ-ENV-001'> EnvironmentalRequirement {
		doc /* 
		The Bourdon gauge shall operate reliably in industrial process 
		environments with specified temperature and vibration conditions.
		*/
		
		assume constraint temperatureRange {
			doc /* Operating temperature: -40°C to 120°C */
		}
		
		assume constraint vibrationTolerance {
			doc /* Withstand vibration up to 10g peak acceleration */
		}
	}
	
	requirement <'REQ-SYS-001'> systemRequirement {
		doc /* 
		The Bourdon gauge system shall provide reliable, accurate pressure 
		measurement for industrial fluid systems through mechanical conversion 
		of pressure to visual indication.
		*/
		
		require constraint primaryFunction :> PrimaryFunctionRequirement;
		require constraint measurementAccuracy :> MeasurementAccuracyRequirement;
		require constraint operatingRange :> OperatingRangeRequirement;
		require constraint responseTime :> ResponseTimeRequirement;
		require constraint environmental :> EnvironmentalRequirement;
	}
	
	part bourdonGauge : BourdonGauge {
		doc /* 
		The Bourdon gauge system is a mechanical pressure measurement instrument 
		that converts fluid pressure into a visual reading. Its primary function 
		is to provide continuous, direct indication of process pressure through 
		mechanical means without requiring external power.
		
		When pressurized fluid enters the Bourdon tube through the process 
		connection, the curved tube experiences elastic deformation that causes 
		its free end to move. This small linear displacement is mechanically 
		amplified and converted to rotational motion through a precision linkage 
		mechanism. The resulting rotation drives a pointer across a calibrated 
		dial face, providing an immediate visual indication of the applied pressure.
		
		The system operates continuously and passively, responding proportionally 
		to pressure changes. The mechanical design ensures that the pointer position 
		directly corresponds to the magnitude of applied pressure, enabling operators 
		to monitor process conditions at a glance without electronic instrumentation.
		*/
		
		attribute actualPressure : PressureValue;
		attribute indicatedPressure : PressureValue;
		attribute responseTime : TimeValue;
		attribute operationalMode : String;
		attribute systemPressure : PressureValue;
		attribute pressureStabilized : Boolean;
		
		part tube : BourdonTube {
			attribute material = "beryllium copper";
			attribute crossSection = "elliptical";
			attribute curvatureRadius = 30.0 [SI::mm];
		}
		
		part linkage : LinkageMechanism {
			attribute leverRatio = 8.5;
			attribute gearRatio = 12.0;
		}
		
		part pointer : PointerAssembly {
			attribute pointerLength = 35.0 [SI::mm];
			attribute currentPosition = 0.0;
		}
		
		part dial : DialFace {
			attribute minimumPressure = 0.0 [SI::Pa];
			attribute maximumPressure = 10000000.0 [SI::Pa];
			attribute numberOfDivisions = 100;
			attribute pressureUnits = "MPa";
		}
		
		part housing : EnclosureHousing {
			attribute housingMaterial = "stainless steel 316";
			attribute connectionType = "1/2 NPT bottom mount";
			attribute windowMaterial = "polycarbonate";
		}
		
		connect housing.processConnection to tube.pressureInput;
		connect tube.mechanicalOutput to linkage.mechanicalInput;
		connect linkage.rotationalOutput to pointer.rotationalInput;
		
		perform action measurePressure : MeasureFluidPressure[*] ordered {
			in appliedPressure = bourdonGauge.actualPressure;
			in tubeProperties = 1.0;
			in linkageRatio = bourdonGauge.linkage.leverRatio * bourdonGauge.linkage.gearRatio;
			in calibration = 1.0;
			out indicatedPressure;
		}
		
		exhibit state operatingStates : GaugeOperationalStates {
			in currentPressure = bourdonGauge.systemPressure;
			in stabilized = bourdonGauge.pressureStabilized;
		}
		
		satisfy primaryFunctionReq : PrimaryFunctionRequirement {
			subject gauge = bourdonGauge;
		}
		satisfy measurementAccuracyReq : MeasurementAccuracyRequirement {
			subject gauge = bourdonGauge;
		}
		satisfy operatingRangeReq : OperatingRangeRequirement {
			subject gauge = bourdonGauge;
		}
		satisfy responseTimeReq : ResponseTimeRequirement {
			subject gauge = bourdonGauge;
		}
		satisfy environmentalReq : EnvironmentalRequirement;
	}
}
