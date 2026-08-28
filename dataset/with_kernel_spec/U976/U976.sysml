package 'Artificial Muscle Actuator System' {
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		private import ISQ::*;

		attribute def Activate;
		attribute def Deactivate;
		attribute def ForceReached;
		attribute def Relaxed;

		alias Voltage for ElectricPotential;
		alias Force for ForceValue;
		alias Length for LengthValue;

		action def 'Apply Voltage' {
			in voltageCmd : Voltage;
			out voltage : Voltage;
		}

		action def 'Contract Fiber' {
			in voltage : Voltage;
			out force : Force;
		}

		action def 'Measure Force' {
			in force : Force;
			out measuredForce : Force;
		}

		action def 'Control Activation' {
			in activateCmd : Activate;
			in measuredForce : Force;
			out voltageCmd : Voltage;
		}

		action def 'Relax Fiber' {
			out force : Force;
		}

		action def 'Actuate' {
			in activateCmd : Activate;
			in deactivateCmd : Deactivate;
		}

		part def ElectroactivePolymerFiber {
			attribute restingLength : Length;
			attribute contractedLength : Length;
			port voltageInPort {
				in voltage : Voltage;
			}
			port forceOutPort {
				out force : Force;
			}
			perform 'Contract Fiber';
			perform 'Relax Fiber';
		}

		part def HighVoltagePowerSupply {
			port controlInPort {
				in voltageCmd : Voltage;
			}
			port voltageOutPort {
				out voltage : Voltage;
			}
			perform 'Apply Voltage';
		}

		part def MicrocontrollerUnit {
			port activateInPort {
				in activateCmd : Activate;
			}
			port deactivateInPort {
				in deactivateCmd : Deactivate;
			}
			port forceInPort {
				in measuredForce : Force;
			}
			port voltageCmdOutPort {
				out voltageCmd : Voltage;
			}
			perform 'Control Activation';
		}

		part def ForceSensor {
			port forceInPort {
				in force : Force;
			}
			port forceOutPort {
				out measuredForce : Force;
			}
			perform 'Measure Force';
		}

		part def MechanicalLoad {
			port forceInPort {
				in appliedForce : Force;
			}
		}

		part def ActuatorSystem {
			port commandPort {
				in activateCmd : Activate;
				in deactivateCmd : Deactivate;
			}
			part fiber : ElectroactivePolymerFiber;
			part powerSupply : HighVoltagePowerSupply;
			part microcontroller : MicrocontrollerUnit;
			part forceSensor : ForceSensor;
			part load : MechanicalLoad;

			connection activateCmdConn from commandPort.activateCmd to microcontroller.activateInPort.activateCmd;
			connection deactivateCmdConn from commandPort.deactivateCmd to microcontroller.deactivateInPort.deactivateCmd;
			connection voltageCmdConn from microcontroller.voltageCmdOutPort.voltageCmd to powerSupply.controlInPort.voltageCmd;
			connection voltageConn from powerSupply.voltageOutPort.voltage to fiber.voltageInPort.voltage;
			connection forceConn from fiber.forceOutPort.force to forceSensor.forceInPort.force;
			connection measuredForceConn from forceSensor.forceOutPort.measuredForce to microcontroller.forceInPort.measuredForce;
			connection loadForceConn from fiber.forceOutPort.force to load.forceInPort.appliedForce;
		}

		requirement def ActuatorRequirements {
			doc /* Defines performance and safety constraints for the artificial muscle actuator. */
			attribute maxOperatingVoltage : Voltage;
			attribute minOutputForce : Force;
			attribute minContractionRatio : Real;
		}
	}

	package Usages {
		part actuator : ActuatorSystem {
			action 'actuate' : 'Actuate' {
				in activateCmd = commandPort.activateCmd;
				in deactivateCmd = commandPort.deactivateCmd;
				loop {
					accept act : Activate;
					then action {
						action 'control activation' : 'Control Activation' {
							in activateCmd = act;
							in measuredForce : Force;
							out voltageCmd : Voltage;
						}
						flow 'control activation'.voltageCmd to 'apply voltage'.voltageCmd;
						action 'apply voltage' : 'Apply Voltage' {
							in voltageCmd : Voltage;
							out voltage : Voltage;
						}
						flow 'apply voltage'.voltage to 'contract fiber'.voltage;
						action 'contract fiber' : 'Contract Fiber' {
							in voltage : Voltage;
							out force : Force;
						}
						flow 'contract fiber'.force to 'measure force'.force;
						action 'measure force' : 'Measure Force' {
							in force : Force;
							out measuredForce : Force;
						}
						flow 'measure force'.measuredForce to 'control activation'.measuredForce;
					}
					then accept deact : Deactivate;
					then action 'relax fiber' : 'Relax Fiber' {
						out force : Force;
					}
				}
			}
		}

		requirement actuatorSpec : ActuatorRequirements {
			subject = actuator;
			maxOperatingVoltage = 3000 [V];
			minOutputForce = 50 [N];
			minContractionRatio = 0.15;
		}
	}
}
