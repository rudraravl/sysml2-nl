package MERCI_Retriever_System {
	private import ScalarValues::*;

	package Definitions {
		item def Blood;
		item def Thrombus {
			attribute size : LengthValue;
			attribute location : String;
		}
		item def XRayImage;
		item def DeploySignal;
		item def WithdrawSignal;
		item def AspirateSignal;

		attribute def LengthValue :> Real { doc /* unit: mm */ }
		attribute def PressureValue :> Real { doc /* unit: mmHg */ }
		attribute def DurationValue :> Real { doc /* unit: s */ }
		attribute def AttemptCount :> Integer;

		port def FluidPort {
			out item blood : Blood;
		}
		port def ImagePort {
			out item image : XRayImage;
		}
		port def ControlPort {
			out item deploy : DeploySignal;
			out item withdraw : WithdrawSignal;
			out item aspirate : AspirateSignal;
		}
		port def SuctionPort {
			in item suction : PressureValue;
		}
		port def ChannelPort;

		part def GuideCatheter {
			port proximalPort : FluidPort;
			port distalPort : ~FluidPort;
			port aspirationPort : SuctionPort;
			attribute length : LengthValue;
		}

		part def Microcatheter {
			port proximalPort : ~FluidPort;
			port distalPort : FluidPort;
			port channelPort : ChannelPort;
			attribute length : LengthValue;
			attribute flexibility : Real;
		}

		part def MERCIRetriever {
			attribute filamentDiameter : LengthValue;
			attribute loopDiameter : LengthValue;
			port controlPort : ~ControlPort;
			port channelPort : ~ChannelPort;

			state {
				entry; then undeployed;
				state undeployed;
				transition from undeployed to deployed
					accept DeploySignal;
				state deployed;
				transition from deployed to withdrawn
					accept WithdrawSignal;
				state withdrawn;
			}
		}

		part def AspirationPump {
			port suctionPort : SuctionPort;
			port controlPort : ~ControlPort;
			attribute suctionPressure : PressureValue;

			state {
				entry; then inactive;
				state inactive;
				transition from inactive to active
					accept AspirateSignal;
				state active;
			}
		}

		part def FluoroscopySystem {
			port imagePort : ImagePort;
			attribute frameRate : Real;
		}

		part def Surgeon {
			port imageInPort : ~ImagePort;
			port retrieverControl : ControlPort;
			port pumpControl : ControlPort;
		}

		part def BloodVessel {
			port proximalPort : FluidPort;
			port distalPort : ~FluidPort;
			attribute diameter : LengthValue;
			attribute name : String;
			item blood : Blood;
			item clot : Thrombus[0..1];
		}

		part def Patient {
			part accessVessel : BloodVessel {
				attribute :>> name = "Femoral Artery";
			}
			part neckVessel : BloodVessel {
				attribute :>> name = "Carotid Artery";
			}
			part brainVessel : BloodVessel {
				attribute :>> name = "Middle Cerebral Artery";
				item clot : Thrombus[1] {
					attribute :>> size = 8.0;
					attribute :>> location = "MCA M1 segment";
				}
			}
			connection accessToNeck {
				end accessVessel.distalPort;
				end neckVessel.proximalPort;
			}
			connection neckToBrain {
				end neckVessel.distalPort;
				end brainVessel.proximalPort;
			}
		}

		action def InsertGuideCatheter {
			out pathwayEstablished : Boolean;
		}

		action def NavigateMicrocatheter {
			in guidePathway : Boolean;
			out microcatheterPositioned : Boolean;
		}

		action def DeployRetriever {
			in positioned : Boolean;
			out retrieverDeployed : Boolean;
		}

		action def DwellAtClot {
			in deployed : Boolean;
			attribute dwellTime : DurationValue;
			out clotEngaged : Boolean;
		}

		action def WithdrawRetriever {
			in engaged : Boolean;
			out clotExtracted : Thrombus;
		}

		action def ActivateAspiration {
			out suctionActive : Boolean;
		}

		action def AssessBloodFlow {
			out flowStatus : Boolean;
		}

		action def PerformThrombectomy {
			in maxAttempts : AttemptCount;
			out reperfusionAchieved : Boolean;
			out extractedClot : Thrombus;
		}
	}

	package Requirements {
		private import Definitions::*;

		requirement def RestoreBloodFlow {
			doc /* The system shall restore blood flow to affected brain tissue by extracting the thrombus. */
			subject patient : Patient;
		}

		requirement def LimitAttempts {
			doc /* The thrombectomy process shall be repeated no more than a maximum number of attempts. */
			attribute maxAttempts : AttemptCount = 6;
		}

		requirement def AspirationDuringWithdrawal {
			doc /* The aspiration pump shall be activated during withdrawal to capture clot fragments. */
		}

		requirement def DwellTimeRequirement {
			doc /* The retriever shall dwell at the clot for a set period to fully engage. */
			attribute minDwellTime : DurationValue = 2.0;
		}

		requirement def MonitorWithFluoroscopy {
			doc /* The entire procedure shall be monitored using real-time X-ray imaging. */
		}
	}

	package Usages {
		private import Definitions::*;
		private import Requirements::*;

		part merciSystem {
			part guideCatheter : GuideCatheter {
				attribute :>> length = 90.0;
			}
			part microcatheter : Microcatheter {
				attribute :>> length = 150.0;
				attribute :>> flexibility = 0.85;
			}
			part retriever : MERCIRetriever {
				attribute :>> filamentDiameter = 0.05;
				attribute :>> loopDiameter = 3.0;
			}
			part aspirationPump : AspirationPump {
				attribute :>> suctionPressure = -0.5;
			}
			part fluoroscopy : FluoroscopySystem {
				attribute :>> frameRate = 30.0;
			}
			part surgeon : Surgeon;
			part patient : Patient;

			connection guideToMicro {
				end guideCatheter.distalPort;
				end microcatheter.proximalPort;
			}
			connection microToBrain {
				end microcatheter.distalPort;
				end patient.brainVessel.proximalPort;
			}
			connection aspirationToGuide {
				end aspirationPump.suctionPort;
				end guideCatheter.aspirationPort;
			}
			connection retrieverInMicro {
				end retriever.channelPort;
				end microcatheter.channelPort;
			}
			connection fluoroToSurgeon {
				end fluoroscopy.imagePort;
				end surgeon.imageInPort;
			}
			connection surgeonToRetriever {
				end surgeon.retrieverControl;
				end retriever.controlPort;
			}
			connection surgeonToPump {
				end surgeon.pumpControl;
				end aspirationPump.controlPort;
			}

			requirement restoreBloodFlowReq : RestoreBloodFlow;
			requirement limitAttemptsReq : LimitAttempts;
			requirement aspirationReq : AspirationDuringWithdrawal;
			requirement dwellTimeReq : DwellTimeRequirement;
			requirement monitorReq : MonitorWithFluoroscopy;

			perform action performThrombectomy : PerformThrombectomy {
				in maxAttempts : AttemptCount = 6;
				out reperfusionAchieved : Boolean;
				out extractedClot : Thrombus;

				action insertGuide : InsertGuideCatheter {
					out pathwayEstablished : Boolean = true;
				}
				then action navigateMicro : NavigateMicrocatheter {
					in guidePathway = insertGuide.pathwayEstablished;
					out microcatheterPositioned : Boolean = true;
				}
				then action deployRetriever : DeployRetriever {
					in positioned = navigateMicro.microcatheterPositioned;
					out retrieverDeployed : Boolean = true;
				}
				then action dwell : DwellAtClot {
					in deployed = deployRetriever.retrieverDeployed;
					attribute :>> dwellTime = 3.0;
					out clotEngaged : Boolean = true;
				}
				then action withdrawAndAspirate {
					action withdraw : WithdrawRetriever {
						in engaged = dwell.clotEngaged;
						out clotExtracted : Thrombus;
					}
					action activateAspiration : ActivateAspiration {
						out suctionActive : Boolean = true;
					}
				}
				then action assess : AssessBloodFlow {
					out flowStatus : Boolean;
				}
			}

			satisfy restoreBloodFlowReq by performThrombectomy;
			satisfy limitAttemptsReq by performThrombectomy;
			satisfy aspirationReq by performThrombectomy.withdrawAndAspirate.activateAspiration;
			satisfy dwellTimeReq by performThrombectomy.dwell;
			satisfy monitorReq by fluoroscopy;
		}
	}
}
