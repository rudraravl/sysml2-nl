package DifferentialSystem {

	import ISQ::*;
	import ScalarValues::*;

	// ---- Value types ----

	value def Torque :> Real {
		unit Nm;
	}
	value def RotationalSpeed :> Real {
		unit rpm;
	}
	value def Power :> Real {
		unit W;
	}
	value def Angle :> Real {
		unit 'rad';
	}
	value def Mass :> Real {
		unit kg;
	}

	// ---- Item flows ----

	item def MechanicalPower {
		attr torque : Torque;
		attr speed : RotationalSpeed;
	}

	// ---- Interfaces / port types ----

	port def RotationalPort {
		in power : MechanicalPower;
	}

	// ---- Requirements ----

	requirement def StructuralIntegrity {
		doc /* All components must withstand maximum rated engine torque without failing. */
		subject : DifferentialSystem;
		attr maxRatedTorque : Torque = 400 [Nm];
		constraint { subject.maxInputTorque <= maxRatedTorque }
	}

	requirement def EvenTorqueDistribution {
		doc /* In straight driving, torque is distributed equally to both axles. */
		subject : DifferentialGearSet;
		constraint { subject.leftAxleTorque == subject.rightAxleTorque }
	}

	requirement def DifferentialSpeedOperation {
		doc /* During cornering, output axle speeds may differ while power is delivered to both. */
		subject : DifferentialGearSet;
		constraint { subject.leftAxleSpeed != subject.rightAxleSpeed }
	}

	requirement def PowerContinuity {
		doc /* Power delivered to both wheels equals input power minus losses. */
		subject : DifferentialGearSet;
		attr efficiency : Real = 0.97;
		constraint {
			subject.leftAxlePower + subject.rightAxlePower
				<= efficiency * subject.inputPower
		}
	}

	// ---- Parts ----

	part def Driveshaft {
		port in inputPort : RotationalPort;
		port out outputPort : RotationalPort;
		attr length : Real = 1.2 [m];
		attr diameter : Real = 0.06 [m];
		attr materialYield : Torque = 600 [Nm];
		attr maxInputTorque : Torque = 400 [Nm];

		action transmitPower {
			in p : MechanicalPower;
			out q : MechanicalPower;
		}
	}

	part def Axle {
		port in inputPort : RotationalPort;
		port out wheelPort : RotationalPort;
		attr side : String;
		attr length : Real = 0.8 [m];
		attr diameter : Real = 0.04 [m];
		attr materialYield : Torque = 500 [Nm];
		attr currentTorque : Torque;
		attr currentSpeed : RotationalSpeed;
	}

	part def WheelHub {
		port in axlePort : RotationalPort;
		attr radius : Real = 0.31 [m];
		attr mass : Mass = 18 [kg];
		attr currentSpeed : RotationalSpeed;
	}

	part def DifferentialGearSet {
		port in inputPort : RotationalPort;
		port out leftOutputPort : RotationalPort;
		port out rightOutputPort : RotationalPort;

		attr maxInputTorque : Torque = 400 [Nm];
		attr gearRatio : Real = 3.73;
		attr carrierSpeed : RotationalSpeed;
		attr leftAxleTorque : Torque;
		attr rightAxleTorque : Torque;
		attr leftAxleSpeed : RotationalSpeed;
		attr rightAxleSpeed : RotationalSpeed;
		attr inputPower : Power;
		attr leftAxlePower : Power;
		attr rightAxlePower : Power;

		part ringGear {
			attr teeth : Integer = 41;
			attr materialYield : Torque = 800 [Nm];
		}
		part pinionGear {
			attr teeth : Integer = 11;
			attr materialYield : Torque = 800 [Nm];
		}
		part sideGearLeft {
			attr teeth : Integer = 16;
			attr materialYield : Torque = 700 [Nm];
		}
		part sideGearRight {
			attr teeth : Integer = 16;
			attr materialYield : Torque = 700 [Nm];
		}
		part spiderGears[2] {
			attr teeth : Integer = 10;
			attr materialYield : Torque = 600 [Nm];
		}

		// Behavior: operating state machine
		state def Behavior {
			entry; then idle;

			state idle {
				entry { carrierSpeed = 0 [rpm]; }
				constraint { carrierSpeed == 0 [rpm] }
			}

			state straightDriving {
				entry {
					leftAxleSpeed = carrierSpeed;
					rightAxleSpeed = carrierSpeed;
					leftAxleTorque = inputPort.power.torque / 2;
					rightAxleTorque = inputPort.power.torque / 2;
				}
				constraint {
					leftAxleSpeed == rightAxleSpeed
					and leftAxleTorque == rightAxleTorque
				}
			}

			state cornering {
				entry {
					leftAxleSpeed = carrierSpeed + deltaSpeed;
					rightAxleSpeed = carrierSpeed - deltaSpeed;
				}
				attr deltaSpeed : RotationalSpeed;
				constraint {
					(leftAxleSpeed + rightAxleSpeed) / 2 == carrierSpeed
					and leftAxleSpeed != rightAxleSpeed
				}
			}

			transition from idle to straightDriving
				when inputPort.power.speed > 0 [rpm];

			transition from straightDriving to cornering
				when abs(leftAxleSpeed - rightAxleSpeed) > 0 [rpm];

			transition from cornering to straightDriving
				when leftAxleSpeed == rightAxleSpeed;

			transition from straightDriving to idle
				when inputPort.power.speed == 0 [rpm];

			transition from cornering to idle
				when inputPort.power.speed == 0 [rpm];
		}

		compose behavior : Behavior;

		action distributePower {
			in p : MechanicalPower;
			out left : MechanicalPower;
			out right : MechanicalPower;
		}
	}

	part def DifferentialSystem {
		port in enginePort : RotationalPort;
		port out leftWheelPort : RotationalPort;
		port out rightWheelPort : RotationalPort;

		attr maxInputTorque : Torque = 400 [Nm];

		part driveshaft : Driveshaft;
		part gearSet : DifferentialGearSet;
		part leftAxle : Axle { side = "left"; }
		part rightAxle : Axle { side = "right"; }
		part leftWheel : WheelHub;
		part rightWheel : WheelHub;

		// Connections
		connect enginePort to driveshaft.inputPort;
		connect driveshaft.outputPort to gearSet.inputPort;
		connect gearSet.leftOutputPort to leftAxle.inputPort;
		connect gearSet.rightOutputPort to rightAxle.inputPort;
		connect leftAxle.wheelPort to leftWheel.axlePort;
		connect rightAxle.wheelPort to rightWheel.axlePort;
		connect leftWheel.axlePort to leftWheelPort;
		connect rightWheel.axlePort to rightWheelPort;

		// Requirement satisfaction
		satisfy StructuralIntegrity {
			subject = DifferentialSystem::this;
		}
		satisfy EvenTorqueDistribution {
			subject = gearSet;
		}
		satisfy DifferentialSpeedOperation {
			subject = gearSet;
		}
		satisfy PowerContinuity {
			subject = gearSet;
		}
	}

}
