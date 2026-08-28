package AngleSensitivePixelModel {
	attribute def Angle :> ScalarValues::Real;
	attribute def Intensity :> ScalarValues::Real;
	attribute def Voltage :> ScalarValues::Real;
	attribute def Confidence :> ScalarValues::Real;
	attribute def Timestamp :> ScalarValues::Real;

	item def Light {
		attribute intensity : Intensity;
		attribute angle : Angle;
	}

	item def ElectricalSignal {
		attribute amplitude : Voltage;
	}

	item def AngleDataPacket {
		attribute angle : Angle;
		attribute confidence : Confidence;
		attribute timestamp : Timestamp;
	}

	attribute def LightDetected;
	attribute def MeasurementComplete;

	part def Microlens {
		in port lightIn : Light;
		out port lightOut : Light;
	}

	part def DiffractionGrating {
		attribute gratingPeriod : ScalarValues::Real;
		in port lightIn : Light;
		out port lightOut : Light;
	}

	part def Photodetector {
		in port lightIn : Light;
		out port signalOut : ElectricalSignal;
	}

	action def ComputeAngle {
		in s1 : ElectricalSignal;
		in s2 : ElectricalSignal;
		out packet : AngleDataPacket;
	}

	part def AngleComputationUnit {
		in port signal1 : ElectricalSignal;
		in port signal2 : ElectricalSignal;
		out port dataOut : AngleDataPacket;
		attribute calibrationMatrix : ScalarValues::Real[2];
	}

	part def AngleSensitivePixel {
		in port lightInput : Light;
		out port dataOutput : AngleDataPacket;

		part microlens : Microlens;
		part grating1 : DiffractionGrating { attribute gratingPeriod = 1.0; }
		part grating2 : DiffractionGrating { attribute gratingPeriod = 1.1; }
		part pd1 : Photodetector;
		part pd2 : Photodetector;
		part acu : AngleComputationUnit;

		connect lightInput to microlens.lightIn;
		connect microlens.lightOut to grating1.lightIn;
		connect microlens.lightOut to grating2.lightIn;
		connect grating1.lightOut to pd1.lightIn;
		connect grating2.lightOut to pd2.lightIn;
		connect pd1.signalOut to acu.signal1;
		connect pd2.signalOut to acu.signal2;
		connect acu.dataOut to dataOutput;

		state ASPBehavior {
			entry; then idle;
			state idle {
				do action lowPowerMode;
			}
			accept LightDetected then ready;
			state ready {
				do action powerUp;
			}
			accept LightDetected then measuring;
			state measuring {
				do action ComputeAngle {
					in s1 = pd1.signalOut;
					in s2 = pd2.signalOut;
					out packet = dataOutput;
				}
			}
			accept MeasurementComplete then idle;
		}
	}

	action def lowPowerMode;
	action def powerUp;

	requirement def AngleMeasurementRequirement {
		doc /* The pixel shall measure the angle of incoming light. The measured angle must be within 1 degree of the actual angle. */
	}

	requirement def PowerEfficiencyRequirement {
		doc /* The pixel shall consume less than 10 microwatts in idle mode. */
	}

	requirement def DualGratingDesignRequirement {
		doc /* The pixel shall use two diffraction gratings with different periods. */
	}

	satisfy AngleMeasurementRequirement by AngleSensitivePixel.acu;
	satisfy PowerEfficiencyRequirement by AngleSensitivePixel.ASPBehavior.idle;
	satisfy DualGratingDesignRequirement by AngleSensitivePixel.grating1;
	satisfy DualGratingDesignRequirement by AngleSensitivePixel.grating2;
}
