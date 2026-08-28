package 'Handheld Electrical Test Light' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;

	package Definitions {
		value def Voltage :> Real;
		value def Current :> Real;
		value def Resistance :> Real;
		value def Brightness :> Real;

		item def Electricity;

		port def ElectricalPort {
			out item electricity : Electricity;
		}

		part def InsulatedHandle {
			attribute insulationRating : Voltage;
		}

		part def WireLead {
			attribute length : Real;
		}

		part def MetalProbe {
			port contactPort : ~ElectricalPort;
		}

		part def IncandescentLamp {
			port lampInPort : ~ElectricalPort;
			port lampOutPort : ElectricalPort;
			attribute brightness : Brightness;
			attribute ratedVoltage : Voltage;
			attribute isIlluminated : Boolean;
		}

		part def CurrentLimitingResistor {
			port resistorInPort : ~ElectricalPort;
			port resistorOutPort : ElectricalPort;
			attribute resistance : Resistance;
		}

		enum def TestLightState {
			enum off;
			enum testing;
			enum illuminatedBright;
			enum illuminatedDim;
		}

		action def TestCircuit {
			in probeAContact : Electricity;
			in probeBContact : Electricity;
			out detectedVoltage : Voltage;
			out hasContinuity : Boolean;
		}

		requirement def VoltageDetectionRequirement {
			subject testLight : IncandescentLamp;
			requirement {
				doc /* The test light must illuminate when a voltage difference above the minimum threshold is detected across the probes. */
				constraint { testLight.isIlluminated == true }
			}
		}

		requirement def ContinuityRequirement {
			subject testLight : IncandescentLamp;
			attribute minVoltage : Voltage = 0.5;
			requirement {
				doc /* The lamp must illuminate when continuity exists and voltage exceeds the minimum threshold. */
				constraint { testLight.isIlluminated == true }
			}
		}

		requirement def SafetyRequirement {
			doc /* The insulated rubber handle must protect the user from electrical shock during testing. */
			subject handle : InsulatedHandle;
			attribute minInsulationRating : Voltage = 600;
			requirement {
				constraint { handle.insulationRating >= minInsulationRating }
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part def TestLight {
			attribute currentState : TestLightState = TestLightState::off;
			attribute minDetectableVoltage : Voltage = 0.5;
			attribute detectedVoltage : Voltage;
			attribute hasContinuity : Boolean;

			part handle : InsulatedHandle {
				attribute redefines insulationRating = 1000;
				part lamp : IncandescentLamp {
					attribute redefines ratedVoltage = 12;
					attribute redefines brightness = 0.0;
					attribute redefines isIlluminated = false;
				}
				part resistor : CurrentLimitingResistor {
					attribute redefines resistance = 1000;
				}
			}

			part leadA : WireLead {
				attribute redefines length = 0.5;
				part probeA : MetalProbe;
			}
			part leadB : WireLead {
				attribute redefines length = 0.5;
				part probeB : MetalProbe;
			}

			connect leadA.probeA.contactPort to handle.resistor.resistorInPort;
			connect handle.resistor.resistorOutPort to handle.lamp.lampInPort;
			connect handle.lamp.lampOutPort to leadB.probeB.contactPort;

			perform action testCircuit : TestCircuit {
				in probeAContact = leadA.probeA.contactPort.electricity;
				in probeBContact = leadB.probeB.contactPort.electricity;
				out detectedVoltage = detectedVoltage;
				out hasContinuity = hasContinuity;
			}

			perform state machine testLightSM {
				state off;
				state testing;
				state illuminatedBright;
				state illuminatedDim;

				transition from off to testing when { detectedVoltage > 0 or hasContinuity == true };
				transition from testing to illuminatedBright when { detectedVoltage >= handle.lamp.ratedVoltage and hasContinuity == true };
				transition from testing to illuminatedDim when { detectedVoltage >= minDetectableVoltage and detectedVoltage < handle.lamp.ratedVoltage and hasContinuity == true };
				transition from testing to off when { detectedVoltage < minDetectableVoltage and hasContinuity == false };
				transition from illuminatedBright to testing when { detectedVoltage < handle.lamp.ratedVoltage or hasContinuity == false };
				transition from illuminatedDim to testing when { detectedVoltage < minDetectableVoltage or hasContinuity == false };
			}

			satisfy voltageReq : VoltageDetectionRequirement {
				subject testLight = handle.lamp;
			}
			satisfy continuityReq : ContinuityRequirement {
				subject testLight = handle.lamp;
			}
			satisfy safetyReq : SafetyRequirement {
				subject handle = handle;
			}
		}
	}
}
