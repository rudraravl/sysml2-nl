package 'WaterHammerMitigationSystem' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def Water;
		item def ControlCommand;

		attribute def PressureValue : Real;

		attribute def ValveCloseCommand;
		attribute def SurgeDetectedSignal;
		attribute def EmergencyAlert;
		attribute def SystemReset;

		port def WaterPort {
			inout item water : Water;
		}

		port def PressureSignalPort {
			out pressure : PressureValue;
		}

		port def FlowSignalPort {
			out flowRate : Real;
		}

		port def ControlPort {
			out command : ControlCommand;
		}

		part def Reservoir {
			port waterOutPort : WaterPort;
			attribute waterLevel : Real;
			item water : Water {
				attribute volume : Real;
			}
		}

		part def Pipeline {
			port waterInPort : ~WaterPort;
			port waterOutPort : WaterPort;
			port upstreamTapPort : WaterPort;
			port downstreamTapPort : WaterPort;
			port surgeTankPort : WaterPort;
			port airVesselPort : WaterPort;
			port reliefValvePort : WaterPort;
			attribute length : Real;
			attribute diameter : Real;
			attribute maxPressure : PressureValue;
			item water : Water {
				attribute volume : Real;
			}
		}

		part def ControlValve {
			port waterInPort : ~WaterPort;
			port waterOutPort : WaterPort;
			port controlPort : ~ControlPort;
			attribute position : Real;
			attribute closingSpeed : Real;
			attribute isOpen : Boolean;
		}

		part def PressureSensor {
			port waterPort : ~WaterPort;
			port signalPort : PressureSignalPort;
			attribute measuredPressure : PressureValue;
		}

		part def FlowMeter {
			port waterPort : ~WaterPort;
			port signalPort : FlowSignalPort;
			attribute measuredFlowRate : Real;
		}

		part def SurgeController {
			port upstreamPressureIn : ~PressureSignalPort;
			port downstreamPressureIn : ~PressureSignalPort;
			port flowIn : ~FlowSignalPort;
			port valveControlOut : ControlPort;
			port surgeTankControlOut : ControlPort;
			port airVesselControlOut : ControlPort;
			port reliefValveControlOut : ControlPort;
			attribute surgeThreshold : PressureValue;
			attribute criticalPressure : PressureValue;
			attribute maxClosingSpeed : Real;
			exhibit state 'surge control states' : SurgeControlStates;
		}

		part def SurgeTank {
			port waterPort : ~WaterPort;
			port controlPort : ~ControlPort;
			attribute volumeMax : Real;
			attribute waterLevel : Real;
			attribute isActive : Boolean;
			item water : Water {
				attribute volume : Real;
			}
		}

		part def AirVessel {
			port waterPort : ~WaterPort;
			port controlPort : ~ControlPort;
			attribute airVolume : Real;
			attribute airPressure : PressureValue;
			attribute preChargePressure : PressureValue;
			attribute isActive : Boolean;
		}

		part def ReliefValve {
			port waterPort : ~WaterPort;
			port dischargePort : WaterPort;
			port controlPort : ~ControlPort;
			attribute thresholdPressure : PressureValue;
			attribute currentPressure : PressureValue;
			attribute isOpen : Boolean;
			exhibit state 'relief valve states' : ReliefValveStates;
		}

		part def DischargePoint {
			port waterInPort : ~WaterPort;
		}

		action def MonitorPipeline {
			in upstreamPressure : PressureValue;
			in downstreamPressure : PressureValue;
			in flowRate : Real;
			out surgeDetected : Boolean;
			out pressureExceedsCritical : Boolean;
		}

		action def ManageValveClosure {
			in currentFlowRate : Real;
			in currentPressure : PressureValue;
			in maxSpeed : Real;
			out valveCommand : ControlCommand;
		}

		action def ActivateSurgeTank;
		action def ActivateAirVessel;
		action def OpenReliefValve;
		action def StabilizeSystem;

		state def SurgeControlStates;
		state def ReliefValveStates;

		requirement def SurgeProtectionRequirement {
			doc /* The system shall detect and mitigate pressure surges to protect the pipeline from water hammer damage. */
			subject pipeline : Pipeline;
			subject surgeController : SurgeController;
			require constraint { surgeController.criticalPressure <= pipeline.maxPressure }
		}

		requirement def ValveClosureControlRequirement {
			doc /* The system shall manage valve closing speed to prevent surge generation during valve closure. */
			subject controlValve : ControlValve;
			subject surgeController : SurgeController;
			require constraint { controlValve.closingSpeed <= surgeController.maxClosingSpeed }
		}

		requirement def ReliefValveRequirement {
			doc /* The relief valve shall automatically open when pressure exceeds critical threshold to prevent catastrophic pipe failure. */
			subject reliefValve : ReliefValve;
			subject pipeline : Pipeline;
			require constraint { reliefValve.thresholdPressure <= pipeline.maxPressure }
		}
	}

	package Usages {
		private import Definitions::*;

		part systemContext {
			part reservoir : Reservoir;

			flow of water : Water
				from reservoir.waterOutPort.water to pipeline.waterInPort.water;

			part pipeline : Pipeline;

			flow of water : Water
				from pipeline.waterOutPort.water to controlValve.waterInPort.water;

			part controlValve : ControlValve;

			flow of water : Water
				from controlValve.waterOutPort.water to downstreamPipeline.waterInPort.water;

			part downstreamPipeline : Pipeline;

			part upstreamPressureSensor : PressureSensor;
			connect pipeline.upstreamTapPort to upstreamPressureSensor.waterPort;
			connect upstreamPressureSensor.signalPort to surgeController.upstreamPressureIn;

			part downstreamPressureSensor : PressureSensor;
			connect downstreamPipeline.upstreamTapPort to downstreamPressureSensor.waterPort;
			connect downstreamPressureSensor.signalPort to surgeController.downstreamPressureIn;

			part flowMeter : FlowMeter;
			connect pipeline.downstreamTapPort to flowMeter.waterPort;
			connect flowMeter.signalPort to surgeController.flowIn;

			part surgeController : SurgeController {
				exhibit state 'surge control states' : SurgeControlStates {
					entry; then monitoring;

					do action monitor : MonitorPipeline {
						in upstreamPressure = upstreamPressureIn.pressure;
						in downstreamPressure = downstreamPressureIn.pressure;
						in flowRate = flowIn.flowRate;
						out surgeDetected;
						out pressureExceedsCritical;
					}

					state monitoring;
					accept ValveCloseCommand
						then valveClosing;
					accept when monitor.surgeDetected
						then mitigating;
					accept when monitor.pressureExceedsCritical
						then mitigating;

					state valveClosing {
						do action manageClosure : ManageValveClosure {
							in currentFlowRate = flowIn.flowRate;
							in currentPressure = upstreamPressureIn.pressure;
							in maxSpeed = maxClosingSpeed;
							out valveCommand = valveControlOut.command;
						}
					}
					accept when monitor.surgeDetected
						then mitigating;
					accept when monitor.pressureExceedsCritical
						then mitigating;
					accept SystemReset
						then monitoring;

					state mitigating {
						entry action activateSurgeTank : ActivateSurgeTank;
						do action activateAirVessel : ActivateAirVessel;
					}
					accept when monitor.pressureExceedsCritical
						then emergencyRelief;
					accept SystemReset
						then stabilizing;

					state emergencyRelief {
						entry action openReliefValve : OpenReliefValve;
					}
					accept SystemReset
						then stabilizing;

					state stabilizing {
						do action stabilize : StabilizeSystem;
					}
					accept SystemReset
						then monitoring;
				}
			}

			part surgeTank : SurgeTank;
			connect pipeline.surgeTankPort to surgeTank.waterPort;
			connect surgeController.surgeTankControlOut to surgeTank.controlPort;

			part airVessel : AirVessel;
			connect pipeline.airVesselPort to airVessel.waterPort;
			connect surgeController.airVesselControlOut to airVessel.controlPort;

			part reliefValve : ReliefValve {
				exhibit state 'relief valve states' : ReliefValveStates {
					entry; then closed;

					state closed;
					accept when currentPressure > thresholdPressure
						then open;
					accept EmergencyAlert
						then open;

					state open;
					accept when currentPressure <= thresholdPressure
						then closed;
					accept SystemReset
						then closed;
				}
			}
			connect pipeline.reliefValvePort to reliefValve.waterPort;
			connect surgeController.reliefValveControlOut to reliefValve.controlPort;

			part dischargePoint : DischargePoint;
			flow of water : Water
				from reliefValve.dischargePort.water to dischargePoint.waterInPort.water;

			connect surgeController.valveControlOut to controlValve.controlPort;
		}

		requirement surgeProtection : SurgeProtectionRequirement {
			subject pipeline = systemContext.pipeline;
			subject surgeController = systemContext.surgeController;
		}

		requirement valveClosureControl : ValveClosureControlRequirement {
			subject controlValve = systemContext.controlValve;
			subject surgeController = systemContext.surgeController;
		}

		requirement reliefValveSafety : ReliefValveRequirement {
			subject reliefValve = systemContext.reliefValve;
			subject pipeline = systemContext.pipeline;
		}

		satisfy surgeProtection by systemContext.surgeController;
		satisfy valveClosureControl by systemContext.controlValve;
		satisfy reliefValveSafety by systemContext.reliefValve;
	}
}
