package 'Bourdon Gauge System' {
	private import ISQ::*;
	private import ScalarValues::*;

	value type Pressure :> Real;
	value type Length :> Real;
	value type Angle :> Real;
	value type Percentage :> Real;

	unit MPa;
	unit psi;
	unit mm;
	unit deg;
	unit percent;

	port def FluidPort {
		attribute pressure : Pressure;
	}
	port def DisplacementPort {
		attribute displacement : Length;
	}
	port def RotationPort {
		attribute angle : Angle;
	}

	connection def FluidConnection {
		end source : FluidPort;
		end target : FluidPort;
	}
	connection def DisplacementConnection {
		end source : DisplacementPort;
		end target : DisplacementPort;
	}
	connection def RotationConnection {
		end source : RotationPort;
		end target : RotationPort;
	}

	part def BourdonTube {
		attribute material : String = "Beryllium Copper";
		attribute crossSection : String = "Elliptical";
		attribute curvature : String = "Curved";
		in port fluidIn : FluidPort;
		out port tipDisplacement : DisplacementPort;
	}

	part def PolycarbonateWindow {
		attribute material : String = "Polycarbonate";
		attribute clarity : String = "Clear";
	}

	part def ThreadedConnection {
		attribute threadStandard : String = "NPT 1/4";
		in port processFluid : FluidPort;
		out port tubeOutlet : FluidPort;
	}

	part def Enclosure {
		attribute material : String = "Stainless Steel";
		part window : PolycarbonateWindow;
		part threadedConnection : ThreadedConnection;
	}

	part def Lever {
		attribute amplificationRatio : Real = 5.0;
	}

	part def Gear {
		attribute gearRatio : Real = 10.0;
		attribute totalAmplification : Real = 50.0;
	}

	part def LinkageMechanism {
		part lever : Lever;
		part gear : Gear;
		in port displacementInput : DisplacementPort;
		out port rotationOutput : RotationPort;
	}

	part def Pointer {
		attribute length : Real = 50;
		attribute material : String = "Aluminum";
	}

	part def CalibratedDial {
		attribute unitLabel : String = "MPa";
		attribute range : Pressure = 100;
		attribute divisions : Integer = 100;
		attribute faceMaterial : String = "Aluminum";
	}

	part def PointerAssembly {
		part pointer : Pointer;
		in port rotationInput : RotationPort;
	}

	requirement def NoExternalPowerRequirement {
		doc /* The gauge shall operate without external power. */
	}

	requirement def AccuracyRequirement {
		doc /* The gauge shall be accurate to within 1.5% of full scale. */
		attribute accuracyLimit : Percentage = 1.5;
	}

	requirement def FastResponseRequirement {
		doc /* The gauge shall respond rapidly to pressure changes. */
		attribute maxResponseTime : Real = 0.5;
	}

	requirement def RobustConstructionRequirement {
		doc /* The assembly shall withstand industrial environments. */
	}

	part def BourdonGauge {
		attribute ambientPressure : Pressure = 0.101325;
		attribute fullScale : Pressure = 100;
		attribute accuracyLimit : Percentage = 1.5;
		attribute responseTime : Real = 0.3;

		part enclosure : Enclosure;
		part bourdonTube : BourdonTube;
		part linkage : LinkageMechanism;
		part pointerAssembly : PointerAssembly;
		part dial : CalibratedDial;

		connection fluidConn : FluidConnection
			connect enclosure.threadedConnection.tubeOutlet to bourdonTube.fluidIn;

		connection dispConn : DisplacementConnection
			connect bourdonTube.tipDisplacement to linkage.displacementInput;

		connection rotConn : RotationConnection
			connect linkage.rotationOutput to pointerAssembly.rotationInput;

		state machine def GaugeOperation {
			attribute activePressure : Pressure;
			attribute lastStablePressure : Pressure = 0.0;
			attribute epsilon : Pressure = 0.001;

			state standby;
			state active {
				entry assign activePressure := bourdonTube.fluidIn.pressure;
			}
			state stable {
				entry assign lastStablePressure := bourdonTube.fluidIn.pressure;
			}

			transition t1 first standby -> active
				when bourdonTube.fluidIn.pressure > ambientPressure + epsilon;
			transition t2 first active -> stable
				when bourdonTube.fluidIn.pressure == activePressure;
			transition t3 first stable -> active
				when bourdonTube.fluidIn.pressure != lastStablePressure;
			transition t4 first active -> standby
				when bourdonTube.fluidIn.pressure <= ambientPressure + epsilon;
			transition t5 first stable -> standby
				when bourdonTube.fluidIn.pressure <= ambientPressure + epsilon;
		}

		perform gaugeBehavior : GaugeOperation;
	}

	part bourdonGauge : BourdonGauge;

	requirement noPowerReq : NoExternalPowerRequirement;
	requirement accuracyReq : AccuracyRequirement;
	requirement fastResponseReq : FastResponseRequirement;
	requirement robustReq : RobustConstructionRequirement;

	satisfy noPowerReq by bourdonGauge;
	satisfy accuracyReq by bourdonGauge.linkage;
	satisfy fastResponseReq by bourdonGauge.bourdonTube;
	satisfy robustReq by bourdonGauge.enclosure;

	action def CalibrateGauge {
		in gauge : BourdonGauge;
		in referencePressure : Pressure;
		out calibrated : Boolean;

		action applyReferencePressure {
			assign gauge.enclosure.threadedConnection.processFluid.pressure := referencePressure;
		}
		then action verifyReading {
			assign calibrated := (gauge.bourdonTube.fluidIn.pressure - referencePressure) <= (gauge.fullScale * gauge.accuracyLimit / 100.0);
		}
	}
}
