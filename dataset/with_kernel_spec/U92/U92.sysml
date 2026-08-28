package 'Medical Fluid Delivery System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package 'Value Types and Items' {
		attribute def Volume :> ISQ::volume;
		attribute def Force :> ISQ::force;
		
		item def MedicationFluid;
	}

	package Definitions {
		port def FluidPort {
			in item fluidIn : MedicationFluid;
			out item fluidOut : MedicationFluid;
		}

		part def AntimicrobialBarrier {
			attribute materialCoating : String;
		}

		part def MechanicalValve {
			attribute isOpen : Boolean = false;
		}

		part def ActivationMechanism {
			attribute activationForce :> Force;
		}

		part def SyringeAdapter {
			attribute lockType : String = "Luer-Lock";
		}

		part def NeedlelessConnector {
			port proximalPort : FluidPort;
			port distalPort : FluidPort;
			part antimicrobialBarrier : AntimicrobialBarrier;
			part mechanicalValve : MechanicalValve;
			part activationMechanism : ActivationMechanism;
			
			exhibit state ConnectorStateBehavior {
				state disconnected;
				state connected;
				transition from disconnected to connected;
				transition from connected to disconnected;
			}
		}

		part def FluidReservoir {
			port fluidOutPort : FluidPort;
			attribute volume : Volume;
		}

		part def IVLine {
			port fluidInPort : FluidPort;
		}

		part def Patient {
			port ivAccessPort : FluidPort;
		}

		action def AdministerMedication {
			in item fluid : MedicationFluid;
			action connectDevice;
			action transferFluid {
				in item fluid : MedicationFluid;
				out item transferredFluid : MedicationFluid;
			}
			action disconnectDevice;
		}
	}

	package Requirements {
		requirement def PreventNeedlestickInjuries {
			doc /* The system shall not use needles for fluid transfer. */
		}
		requirement def MaintainSterility {
			doc /* The system shall maintain a sterile, closed pathway. */
		}
		requirement def PreventLeakage {
			doc /* The connector shall automatically close and seal upon disconnection. */
		}
		requirement def ActivationForceThreshold {
			doc /* The activation mechanism shall require a specific engagement force to open the valve. */
			attribute minForce : Force;
		}

		requirement deliverySystemRequirements {
			requirement req1 : PreventNeedlestickInjuries;
			requirement req2 : MaintainSterility;
			requirement req3 : PreventLeakage;
			requirement req4 : ActivationForceThreshold;
		}
	}

	package Usages {
		part deliverySystem {
			part reservoir : FluidReservoir;
			part connector : NeedlelessConnector {
				perform action administerMedication : AdministerMedication;
			}
			part ivLine : IVLine;
			part patient : Patient;

			connection reservoirToConnector connect reservoir.fluidOutPort to connector.proximalPort;
			connection connectorToIVLine connect connector.distalPort to ivLine.fluidInPort;
			connection ivLineToPatient connect ivLine.fluidInPort to patient.ivAccessPort;
		}
	}
}
