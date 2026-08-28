package MedicalOtoscope {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def ElectricalPower;
	item def LightBeam;
	item def ReflectedLight;
	item def MagnifiedImage {
		attribute magnification : Real = 3.5;
	}

	item def PowerButtonPressed;
	item def IlluminationSwitchActivated;
	item def IlluminationSwitchDeactivated;
	item def LowBatteryAlert;

	attribute def BatteryLevel :> Real;
	attribute def MagnificationFactor :> Real;
	attribute def LuminousIntensity :> ISQ::LuminousIntensity;
	attribute def FocalDistance :> ISQ::Length;

	port def PowerPort {
		inout power : ElectricalPower;
	}
	port def LightPort {
		inout light : LightBeam;
	}
	port def ReflectedLightPort {
		inout reflectedLight : ReflectedLight;
	}
	port def ImagePort {
		inout image : MagnifiedImage;
	}
	port def ControlPort;

	part def BatteryPack {
		attribute chargeLevel : BatteryLevel = 100;
		attribute capacity : ISQ::Energy;
		attribute voltage : ISQ::ElectricPotential;
		port powerOut : PowerPort;
	}

	part def IlluminationSource {
		attribute intensity : LuminousIntensity;
		port powerIn : PowerPort;
		port lightOut : LightPort;
	}

	part def SpeculumTip {
		attribute isAttached : Boolean = true;
		port lightIn : LightPort;
		port reflectedLightOut : ReflectedLightPort;
	}

	part def OpticalSystem {
		attribute magnification : MagnificationFactor = 3.5;
		port reflectedLightIn : ReflectedLightPort;
		port imageOut : ImagePort;
	}

	part def Eyepiece {
		attribute focusAdjustment : FocalDistance;
		port imageIn : ImagePort;
	}

	part def Handle {
		part battery : BatteryPack;
	}

	part def HeadAssy {
		part lightSource : IlluminationSource;
		part speculum : SpeculumTip;
		part optics : OpticalSystem;
		part eyepiece : Eyepiece;

		connect lightSource.lightOut to speculum.lightIn;
		connect speculum.reflectedLightOut to optics.reflectedLightIn;
		connect optics.imageOut to eyepiece.imageIn;
	}

	action def ProvideIllumination {
		out beam : LightBeam;
	}
	action def IssueLowBatteryWarning {
		out alert : LowBatteryAlert;
	}
	action def PerformSelfTest;

	part def Otoscope {
		part handle : Handle;
		part head : HeadAssy;

		attribute batteryLevel : BatteryLevel = handle.battery.chargeLevel;

		port controlPort : ControlPort;

		connect handle.battery.powerOut to head.lightSource.powerIn;

		exhibit state OtoscopeStates {
			entry; then powerOff;

			state powerOff;
			accept PowerButtonPressed via controlPort
				then standby;

			state standby {
				entry action performSelfTest : PerformSelfTest;
			}
			accept IlluminationSwitchActivated via controlPort
				then examining;
			accept PowerButtonPressed via controlPort
				then powerOff;

			state examining {
				do action provideIllumination : ProvideIllumination;
			}
			accept IlluminationSwitchDeactivated via controlPort
				then standby;
			accept when batteryLevel < 20
				then lowBatteryWarning;

			state lowBatteryWarning {
				entry action issueLowBatteryWarning : IssueLowBatteryWarning;
			}
			accept PowerButtonPressed via controlPort
				then powerOff;
			accept when batteryLevel < 5
				then powerOff;
		}
	}

	requirement def DiagnosticCapability {
		subject otoscope : Otoscope;
		doc /* The otoscope shall provide clear, magnified, and illuminated views of the external ear canal and eardrum. */;
	}

	requirement def MagnificationRequirement {
		subject optics : OpticalSystem;
		doc /* The optical system shall provide a magnification of approximately 3.5x. */;
		constraint { optics.magnification == 3.5 }
	}

	requirement def IlluminationRequirement {
		subject lightSource : IlluminationSource;
		doc /* The illumination source shall generate a focused beam of light sufficient to illuminate the ear canal. */;
	}

	requirement def BatterySafetyRequirement {
		subject otoscope : Otoscope;
		doc /* The otoscope shall issue a low battery warning when charge drops below 20% and automatically power down when critically low (below 5%). */;
	}

	requirement def ErgonomicHandleRequirement {
		subject handle : Handle;
		doc /* The handle shall provide an ergonomic grip for comfortable use during examinations and shall house the rechargeable battery pack. */;
	}

	satisfy DiagnosticCapability by Otoscope;
	satisfy MagnificationRequirement by Otoscope::head::optics;
	satisfy IlluminationRequirement by Otoscope::head::lightSource;
	satisfy BatterySafetyRequirement by Otoscope::OtoscopeStates;
	satisfy ErgonomicHandleRequirement by Otoscope::handle;

	metadata def SafetyFeature;
	metadata def UsabilityFeature;
	metadata SafetyFeature about Otoscope::handle::battery, Otoscope::OtoscopeStates::lowBatteryWarning;
	metadata UsabilityFeature about Otoscope::head::eyepiece, Otoscope::head::speculum;

	part otoscope : Otoscope;
}
