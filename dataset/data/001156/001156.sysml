package 'Nichols Radiometer System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def RadiationPressure :> ISQ::PressureValue;
	
	attribute def RadiantIntensity :> Real;
	
	attribute def DeflectionAngle :> ISQ::AngleValue;
	
	attribute def TorsionalStiffness :> Real;
	
	attribute def BeamOn;
	attribute def BeamOff;
	
	port def OpticalPort {
		in radiationIntensity : RadiantIntensity;
	}
	
	port def MechanicalPort {
		out deflectionAngle : DeflectionAngle;
	}
	
	port def MeasurementPort {
		out radiationPressure : RadiationPressure;
	}
	
	part def Mirror {
		attribute reflectiveSurfaceArea : ISQ::AreaValue;
		attribute reflectivity : Real;
		attribute mass : ISQ::MassValue;
		port opticalInput : OpticalPort;
		port mechanicalOutput : MechanicalPort;
	}
	
	part def TorsionFiber {
		attribute fiberLength : ISQ::LengthValue;
		attribute fiberDiameter : ISQ::LengthValue;
		attribute stiffness : TorsionalStiffness;
		port mechanicalInput : MechanicalPort;
		attribute currentDeflection : DeflectionAngle;
	}
	
	part def OpticalLever {
		attribute leverArmLength : ISQ::LengthValue;
		attribute magnificationFactor : Real;
		port deflectionInput : MechanicalPort;
		port measurementOutput : MeasurementPort;
	}
	
	part def VacuumChamber {
		attribute internalPressure : ISQ::PressureValue;
		attribute chamberVolume : ISQ::VolumeValue;
		attribute windowTransmittance : Real;
	}
	
	action def AbsorbRadiation {
		in incidentIntensity : RadiantIntensity;
		in mirrorArea : ISQ::AreaValue;
		in reflectivity : Real;
		out absorbedPower : ISQ::PowerValue;
	}
	
	action def CalculateRadiationForce {
		in absorbedPower : ISQ::PowerValue;
		in speedOfLight : ISQ::SpeedValue;
		out radiationForce : ISQ::ForceValue;
	}
	
	action def ComputeTorque {
		in appliedForce : ISQ::ForceValue;
		in leverArm : ISQ::LengthValue;
		out resultingTorque : ISQ::TorqueValue;
	}
	
	action def DetermineDeflection {
		in appliedTorque : ISQ::TorqueValue;
		in fiberStiffness : TorsionalStiffness;
		out deflectionAngle : DeflectionAngle;
	}
	
	action def MeasurePressure {
		in deflectionAngle : DeflectionAngle;
		in fiberStiffness : TorsionalStiffness;
		in mirrorArea : ISQ::AreaValue;
		in leverArm : ISQ::LengthValue;
		out measuredPressure : RadiationPressure;
	}
	
	action def PerformRadiometryMeasurement {
		in radiationInput : RadiantIntensity;
		in mirrorArea : ISQ::AreaValue;
		in reflectivity : Real;
		in fiberStiffness : TorsionalStiffness;
		in leverArm : ISQ::LengthValue;
		in speedOfLight : ISQ::SpeedValue;
		out pressureOutput : RadiationPressure;
		
		first start;
		then action absorb : AbsorbRadiation {
			in incidentIntensity = radiationInput;
			in mirrorArea = mirrorArea;
			in reflectivity = reflectivity;
			out absorbedPower;
		}
		then action calculateForce : CalculateRadiationForce {
			in absorbedPower = absorb.absorbedPower;
			in speedOfLight = speedOfLight;
			out radiationForce;
		}
		then action computeTorque : ComputeTorque {
			in appliedForce = calculateForce.radiationForce;
			in leverArm = leverArm;
			out resultingTorque;
		}
		then action determineDeflection : DetermineDeflection {
			in appliedTorque = computeTorque.resultingTorque;
			in fiberStiffness = fiberStiffness;
			out deflectionAngle;
		}
		then action measurePressure : MeasurePressure {
			in deflectionAngle = determineDeflection.deflectionAngle;
			in fiberStiffness = fiberStiffness;
			in mirrorArea = mirrorArea;
			in leverArm = leverArm;
			out measuredPressure;
		}
		then assign pressureOutput := measurePressure.measuredPressure;
		then done;
	}
	
	action def OperateRadiometer {
		in radiationIntensity : RadiantIntensity;
		in mirrorArea : ISQ::AreaValue;
		in reflectivity : Real;
		in fiberStiffness : TorsionalStiffness;
		in leverArm : ISQ::LengthValue;
		in speedOfLight : ISQ::SpeedValue;
		out continuousPressure : RadiationPressure;
		
		loop {
			accept beamOn : BeamOn;
			then action measurement : PerformRadiometryMeasurement {
				in radiationInput = radiationIntensity;
				in mirrorArea = mirrorArea;
				in reflectivity = reflectivity;
				in fiberStiffness = fiberStiffness;
				in leverArm = leverArm;
				in speedOfLight = speedOfLight;
				out pressureOutput;
			}
			then assign continuousPressure := measurement.pressureOutput;
			then accept beamOff : BeamOff;
		}
	}
	
	part def NicholsRadiometer {
		attribute speedOfLight : ISQ::SpeedValue;
		
		port radiationInput : OpticalPort;
		port pressureOutput : MeasurementPort;
		
		part chamber : VacuumChamber {
			attribute :>> internalPressure = 0.001 [SI::Pa];
			attribute :>> chamberVolume = 0.001 [SI::m^3];
			attribute :>> windowTransmittance = 0.98;
		}
		
		part reflectiveMirror : Mirror {
			attribute :>> reflectiveSurfaceArea = 0.0001 [SI::m^2];
			attribute :>> reflectivity = 0.95;
			attribute :>> mass = 0.0005 [SI::kg];
		}
		
		part suspensionFiber : TorsionFiber {
			attribute :>> fiberLength = 0.15 [SI::m];
			attribute :>> fiberDiameter = 0.00001 [SI::m];
			attribute :>> stiffness = 1.0e-8;
			attribute :>> currentDeflection = 0.0 [SI::rad];
		}
		
		part opticalLever : OpticalLever {
			attribute :>> leverArmLength = 0.05 [SI::m];
			attribute :>> magnificationFactor = 1000.0;
		}
		
		connection opticalPath connect radiationInput to reflectiveMirror.opticalInput;
		connection mechanicalCoupling connect reflectiveMirror.mechanicalOutput to suspensionFiber.mechanicalInput;
		connection readoutPath connect suspensionFiber.mechanicalInput to opticalLever.deflectionInput;
		connection measurementPath connect opticalLever.measurementOutput to pressureOutput;
		
		perform action operate : OperateRadiometer {
			in radiationIntensity = radiationInput.radiationIntensity;
			in mirrorArea = reflectiveMirror.reflectiveSurfaceArea;
			in reflectivity = reflectiveMirror.reflectivity;
			in fiberStiffness = suspensionFiber.stiffness;
			in leverArm = opticalLever.leverArmLength;
			in speedOfLight = speedOfLight;
			out continuousPressure = pressureOutput.radiationPressure;
		}
	}
	
	part radiometerInstance : NicholsRadiometer {
		attribute :>> speedOfLight = 299792458.0 [SI::'m/s'];
	}
	
	requirement def PrimaryFunctionRequirement {
		doc /* The Nichols radiometer shall measure radiation pressure by detecting 
		       the mechanical deflection of a suspended mirror caused by incident 
		       electromagnetic radiation. */
	}
	
	requirement def MeasurementSensitivityRequirement {
		doc /* The radiometer shall be capable of detecting radiation pressure 
		       in the range of 1e-9 to 1e-5 Pa. */
	}
	
	requirement def VacuumRequirement {
		doc /* The measurement chamber shall maintain a vacuum pressure below 
		       0.01 Pa to minimize gas molecule interference. */
	}
	
	requirement <'RAD-001'> primaryFunction : PrimaryFunctionRequirement;
	
	requirement <'RAD-002'> measurementSensitivity : MeasurementSensitivityRequirement;
	
	requirement <'RAD-003'> vacuumCondition : VacuumRequirement;
	
	state def RadiometerStates {
		entry; then idle;
		
		state idle;
		
		transition idle_to_measuring
			first idle
			accept at beamOn : BeamOn
			then measuring;
		
		state measuring;
		
		transition measuring_to_idle
			first measuring
			accept at beamOff : BeamOff
			then idle;
	}
}
