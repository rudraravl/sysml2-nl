package 'Medical Cannula Delivery System' {
	private import ScalarValues::*;

	package Definitions {
		item def MedicalFluid {
			attribute density : Real;
			attribute viscosity : Real;
		}

		item def ControlSignal {
			attribute startDelivery : Boolean;
			attribute stopDelivery : Boolean;
			attribute targetRate : Real;
		}

		item def AlarmSignal {
			attribute signalType : String;
			attribute severity : String;
		}

		port def FluidPort {
			out item fluid : MedicalFluid;
		}

		port def ControlSignalPort {
			out signal : ControlSignal;
		}

		port def AlarmPort {
			out alert : AlarmSignal;
		}

		part def FluidReservoir {
			port fluidOutPort : FluidPort;
			attribute volumeMax : Real = 500;
			attribute volumeCurrent : Real;
			item storedFluid : MedicalFluid {
				attribute volume : Real;
			}
		}

		part def FlowController {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port controlInPort : ~ControlSignalPort;
			port alarmInPort : ~AlarmPort;
			attribute flowRate : Real;
			attribute flowRateMax : Real = 100;
			attribute pressureMax : Real = 300;
			perform action regulateFlow : RegulateFlow;
		}

		part def PressureSensor {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			port alarmOutPort : AlarmPort;
			attribute pressureReading : Real;
			attribute thresholdHigh : Real = 250;
			perform action sensePressure : SensePressure;
		}

		part def CannulaTip {
			attribute material : String = "Medical-grade stainless steel";
			attribute angle : Real;
			attribute sharpness : Real;
		}

		part def CannulaShaft {
			attribute material : String = "Medical-grade stainless steel";
			attribute length : Real = 30;
			attribute innerDiameter : Real = 0.5;
			attribute outerDiameter : Real = 0.8;
			attribute isSterile : Boolean = true;
		}

		part def LuerLockHub {
			attribute connectorStandard : String = "ISO 80369-7";
			attribute isLocked : Boolean;
		}

		part def Cannula {
			port fluidInPort : ~FluidPort;
			port fluidOutPort : FluidPort;
			attribute isSterile : Boolean = true;
			attribute targetInsertionDepth : Real;
			attribute actualInsertionDepth : Real;
			part tip : CannulaTip;
			part shaft : CannulaShaft;
			part hub : LuerLockHub;
		}

		part def PatientTissue {
			attribute tissueType : String;
			attribute maxPressureTolerance : Real;
			attribute currentDepth : Real;
		}

		part def Patient {
			port targetTissuePort : ~FluidPort;
			part targetTissue : PatientTissue;
		}

		interface def FluidInterface {
			end supplierPort : FluidPort;
			end consumerPort : ~FluidPort;
		}

		interface def ControlInterface {
			end source : ControlSignalPort;
			end target : ~ControlSignalPort;
		}

		interface def AlarmInterface {
			end source : AlarmPort;
			end target : ~AlarmPort;
		}

		state def DeliveryProcedureStates;

		action def RegulateFlow;

		action def SensePressure;

		action def PrimeFluidPath {
			in item fluid : MedicalFluid;
			out item primedFluid : MedicalFluid;
		}

		action def InsertCannulaAction {
			in item targetCannula : Cannula;
			attribute depth : Real;
		}

		action def DeliverFluid {
			in item fluid : MedicalFluid;
			attribute rate : Real;
			attribute volume : Real;
		}

		action def RemoveAndDispose {
			in item targetCannula : Cannula;
		}

		action def VerifySterility {
			attribute isSterile : Boolean;
		}

		attribute def StartCommand;
		attribute def StopCommand;
		attribute def AlarmTriggered;
		attribute def AlarmCleared;
		attribute def PrimingComplete;
		attribute def InsertionComplete;
		attribute def DeliveryComplete;
		attribute def RemovalComplete;

		requirement def AccuracyRequirement {
			doc /* The system shall deliver the prescribed volume of medical fluid with an accuracy of at most 0.5 mL deviation. */
		}

		requirement def SafetyRequirement {
			doc /* The system shall not exceed a maximum delivery pressure of 200 kPa to prevent tissue damage. */
		}

		requirement def PerformanceRequirement {
			doc /* The system shall be capable of regulating flow between 1 mL/min and 50 mL/min. */
		}

		requirement def SterilityRequirement {
			doc /* All fluid-path components shall remain sterile until use and be disposed of after single patient use. */
		}

		requirement def CannulaMaterialRequirement {
			doc /* The cannula tip and shaft shall be constructed from medical-grade stainless steel. */
		}
	}

	package Usages {
		private import Definitions::*;

		part deliverySystem {
			part reservoir : FluidReservoir {
				attribute volumeCurrent : Real = 250;
				item storedFluid : MedicalFluid {
					attribute volume : Real = 250;
				}
			}

			part flowController : FlowController {
				attribute flowRate : Real = 10;
			}

			part pressureSensor : PressureSensor;

			part cannula : Cannula {
				attribute targetInsertionDepth : Real = 25;
				part tip : CannulaTip {
					attribute angle : Real = 30;
					attribute sharpness : Real = 0.95;
				}
				part shaft : CannulaShaft {
					attribute length : Real = 30;
					attribute innerDiameter : Real = 0.5;
					attribute outerDiameter : Real = 0.8;
				}
				part hub : LuerLockHub {
					attribute isLocked : Boolean = true;
				}
			}

			part patient : Patient {
				part targetTissue : PatientTissue {
					attribute tissueType : String = "Subcutaneous";
					attribute maxPressureTolerance : Real = 150;
				}
			}

			interface : FluidInterface connect
				supplierPort ::> reservoir.fluidOutPort to
				consumerPort ::> flowController.fluidInPort;

			interface : FluidInterface connect
				supplierPort ::> flowController.fluidOutPort to
				consumerPort ::> pressureSensor.fluidInPort;

			interface : FluidInterface connect
				supplierPort ::> pressureSensor.fluidOutPort to
				consumerPort ::> cannula.fluidInPort;

			interface : FluidInterface connect
				supplierPort ::> cannula.fluidOutPort to
				consumerPort ::> patient.targetTissuePort;

			interface : AlarmInterface connect
				source ::> pressureSensor.alarmOutPort to
				target ::> flowController.alarmInPort;

			flow of fluid : MedicalFluid
				from reservoir.fluidOutPort.fluid to flowController.fluidInPort.fluid;

			flow of fluid : MedicalFluid
				from flowController.fluidOutPort.fluid to pressureSensor.fluidInPort.fluid;

			flow of fluid : MedicalFluid
				from pressureSensor.fluidOutPort.fluid to cannula.fluidInPort.fluid;

			flow of fluid : MedicalFluid
				from cannula.fluidOutPort.fluid to patient.targetTissuePort.fluid;

			flow of alert : AlarmSignal
				from pressureSensor.alarmOutPort.alert to flowController.alarmInPort.alert;

			action 'verify sterility' : VerifySterility {
				attribute isSterile : Boolean = cannula.isSterile;
			}

			action 'prime fluid path' : PrimeFluidPath {
				out item primedFluid : MedicalFluid;
			}

			action 'insert cannula' : InsertCannulaAction {
				attribute depth : Real = cannula.targetInsertionDepth;
			}

			action 'deliver fluid' : DeliverFluid {
				attribute rate : Real = 10;
				attribute volume : Real = 100;
			}

			action 'remove and dispose' : RemoveAndDispose;

			exhibit state procedureStates : DeliveryProcedureStates {
				entry; then idle;

				state idle;
				accept StartCommand then preparation;

				state preparation {
					do 'verify sterility';
					do 'prime fluid path';
				}
				accept PrimingComplete then insertion;

				state insertion {
					do 'insert cannula';
				}
				accept InsertionComplete then delivery;

				state delivery {
					do 'deliver fluid';
				}
				accept AlarmTriggered then alarmState;
				accept DeliveryComplete then removal;

				state alarmState;
				accept AlarmCleared then delivery;

				state removal {
					do 'remove and dispose';
				}
				accept RemovalComplete then idle;
			}
		}

		requirement accReq : AccuracyRequirement;
		requirement safeReq : SafetyRequirement;
		requirement perfReq : PerformanceRequirement;
		requirement sterReq : SterilityRequirement;
		requirement matReq : CannulaMaterialRequirement;

		satisfy accReq by deliverySystem;
		satisfy safeReq by deliverySystem.pressureSensor;
		satisfy perfReq by deliverySystem.flowController;
		satisfy sterReq by deliverySystem.cannula;
		satisfy matReq by deliverySystem.cannula;
	}
}
