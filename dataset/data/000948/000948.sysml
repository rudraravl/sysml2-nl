package 'Treadle Pump Subsystem' {
	private import ScalarValues::*;
	
	attribute def Volume :> Real;
	attribute def Pressure :> Real;
	attribute def Force :> Real;
	attribute def Length :> Real;
	attribute def FlowRate :> Real;
	attribute def Frequency :> Real;
	
	item def Water {
		attribute volume : Volume;
		attribute pressure : Pressure;
		attribute temperature : Real;
	}
	
	port def WaterInPort {
		attribute pressure : Pressure;
		in item waterIn : Water;
	}
	
	port def WaterOutPort {
		attribute pressure : Pressure;
		out item waterOut : Water;
	}
	
	port def MechanicalInputPort {
		attribute appliedForce : Force;
		attribute frequency : Frequency;
	}
	
	part def CheckValve {
		port inletPort : WaterInPort;
		port outletPort : WaterOutPort;
		attribute crackingPressure : Pressure;
		attribute isOpen : Boolean;
		
		assert constraint {
			isOpen == (inletPort.pressure > outletPort.pressure + crackingPressure)
		}
	}
	
	part def PistonChamber {
		port inletPort : WaterInPort;
		port outletPort : WaterOutPort;
		attribute diameter : Length;
		attribute strokeLength : Length;
		attribute currentPosition : Length;
		attribute chamberVolume : Volume;
		
		assert constraint {
			currentPosition >= 0.0 & currentPosition <= strokeLength
		}
	}
	
	part def Treadle {
		port mechanicalInput : MechanicalInputPort;
		attribute treadleLength : Length;
		attribute leverageRatio : Real;
		attribute currentAngle : Real;
		attribute maxAngle : Real;
		
		assert constraint {
			currentAngle >= 0.0 & currentAngle <= maxAngle
		}
	}
	
	part def ConnectingRod {
		attribute rodLength : Length;
		attribute transmittedForce : Force;
	}
	
	part def WaterSource {
		port outletPort : WaterOutPort;
		attribute waterLevel : Length;
		attribute sourceCapacity : Volume;
		item storedWater : Water {
			attribute volume : Volume;
		}
	}
	
	part def DeliveryTank {
		port inletPort : WaterInPort;
		attribute waterLevel : Length;
		attribute tankCapacity : Volume;
		item storedWater : Water {
			attribute volume : Volume;
		}
	}
	
	action def DownStroke {
		in treadleForce : Force;
		in chamberPosition : Length;
		out waterIntake : Water;
		out newPosition : Length;
		
		first start;
		then action applyForce {
			in force = treadleForce;
		}
		then action movePistonDown {
			out position = newPosition;
		}
		then action openInletValve;
		then action drawWaterIn {
			out intake = waterIntake;
		}
		then action closeInletValve;
		then done;
	}
	
	action def UpStroke {
		in chamberPosition : Length;
		in trappedWater : Water;
		out waterDischarge : Water;
		out newPosition : Length;
		
		first start;
		then action releaseTreadle;
		then action movePistonUp {
			out position = newPosition;
		}
		then action openOutletValve;
		then action dischargeWater {
			out discharge = waterDischarge;
		}
		then action closeOutletValve;
		then done;
	}
	
	action def PumpingCycle {
		in operatorForce : Force;
		out deliveredWater : Water;
		out actualFlowRate : FlowRate;
		
		first start;
		then merge continuePumping;
		then action leftDown : DownStroke {
			in treadleForce = operatorForce;
			out waterIntake : Water;
		}
		then action rightUp : UpStroke {
			out waterDischarge : Water;
		}
		then action rightDown : DownStroke {
			in treadleForce = operatorForce;
			out waterIntake : Water;
		}
		then action leftUp : UpStroke {
			out waterDischarge : Water;
		}
		then action combineFlow {
			in leftFlow = leftUp.waterDischarge;
			in rightFlow = rightUp.waterDischarge;
			out combinedFlow = deliveredWater;
		}
		then action calculateFlowRate {
			out flowRate = actualFlowRate;
		}
		then decide;
			if operatorForce > 50.0 then continuePumping;
			if operatorForce <= 50.0 then stopPumping;
		action stopPumping;
		then done;
	}
	
	state def PumpOperatingStates {
		entry; then idle;
		
		state idle {
			entry action {
				doc /* Pump is at rest, no operator input */
			}
		}
		
		transition idle_to_priming
			first idle
			accept OperatorEngaged
			if operatorForce > 50.0
			then priming;
		
		state priming {
			entry action {
				doc /* Initial strokes to fill chambers and establish flow */
			}
		}
		
		transition priming_to_operating
			first priming
			if waterFlowing
			then operating;
		
		state operating {
			entry; then leftDownStroke;
			
			state leftDownStroke {
				entry action {
					doc /* Left treadle pressed, left piston descends */
				}
			}
			
			transition leftDown_to_rightUp
				first leftDownStroke
				accept LeftBottomReached
				then rightUpStroke;
			
			state rightUpStroke {
				entry action {
					doc /* Right treadle released, right piston ascends */
				}
			}
			
			transition rightUp_to_rightDown
				first rightUpStroke
				accept RightTopReached
				then rightDownStroke;
			
			state rightDownStroke {
				entry action {
					doc /* Right treadle pressed, right piston descends */
				}
			}
			
			transition rightDown_to_leftUp
				first rightDownStroke
				accept RightBottomReached
				then leftUpStroke;
			
			state leftUpStroke {
				entry action {
					doc /* Left treadle released, left piston ascends */
				}
			}
			
			transition leftUp_to_leftDown
				first leftUpStroke
				accept LeftTopReached
				then leftDownStroke;
		}
		
		transition operating_to_idle
			first operating
			accept OperatorDisengaged
			if operatorForce <= 50.0
			then idle;
		
		attribute operatorForce : Force;
		attribute waterFlowing : Boolean;
	}
	
	part def TreadlePumpAssembly {
		port sourcePort : ~WaterOutPort;
		port deliveryPort : WaterOutPort;
		port operatorInput : MechanicalInputPort;
		
		part leftTreadle : Treadle;
		part rightTreadle : Treadle;
		part leftRod : ConnectingRod;
		part rightRod : ConnectingRod;
		part leftChamber : PistonChamber;
		part rightChamber : PistonChamber;
		part leftInletValve : CheckValve;
		part rightInletValve : CheckValve;
		part leftOutletValve : CheckValve;
		part rightOutletValve : CheckValve;
		
		attribute designFlowRate : FlowRate;
		attribute maxLiftHeight : Length;
		attribute efficiency : Real;
		
		connection treadleToRodLeft connect leftTreadle to leftRod;
		connection treadleToRodRight connect rightTreadle to rightRod;
		connection rodToPistonLeft connect leftRod to leftChamber;
		connection rodToPistonRight connect rightRod to rightChamber;
		
		flow from sourcePort.waterIn to leftInletValve.inletPort.waterIn;
		flow from sourcePort.waterIn to rightInletValve.inletPort.waterIn;
		flow from leftInletValve.outletPort.waterOut to leftChamber.inletPort.waterIn;
		flow from rightInletValve.outletPort.waterOut to rightChamber.inletPort.waterIn;
		flow from leftChamber.outletPort.waterOut to leftOutletValve.inletPort.waterIn;
		flow from rightChamber.outletPort.waterOut to rightOutletValve.inletPort.waterIn;
		flow from leftOutletValve.outletPort.waterOut to deliveryPort.waterOut;
		flow from rightOutletValve.outletPort.waterOut to deliveryPort.waterOut;
		
		perform action pumpingOperation : PumpingCycle;
		exhibit state pumpStateMachine : PumpOperatingStates;
		
		assert constraint efficiencyConstraint {
			efficiency >= 0.65 & efficiency <= 0.85
		}
	}
	
	requirement def FlowRateRequirement {
		doc /* The treadle pump shall deliver a minimum flow rate under specified operating conditions. */
		attribute minimumFlowRate : FlowRate;
		attribute operatingFrequency : Frequency;
	}
	
	requirement def LiftHeightRequirement {
		doc /* The treadle pump shall lift water to a specified maximum height. */
		attribute maximumLiftHeight : Length;
	}
	
	requirement def DurabilityRequirement {
		doc /* The treadle pump shall operate reliably for a minimum number of cycles. */
		attribute minimumCycles : Real;
	}
	
	requirement def EfficiencyRequirement {
		doc /* The treadle pump shall maintain a minimum mechanical efficiency. */
		attribute minimumEfficiency : Real;
	}
	
	requirement def BackflowPreventionRequirement {
		doc /* The treadle pump shall prevent reverse flow from delivery to source. */
	}
	
	part treadlePumpingSystem {
		doc /* Complete treadle pump subsystem for irrigation or water supply applications. */
		
		part waterSource : WaterSource {
			attribute :>> waterLevel = 3.0;
			attribute :>> sourceCapacity = 5000.0;
			item :>> storedWater {
				attribute :>> volume = 4500.0;
				attribute :>> pressure = 0.0;
				attribute :>> temperature = 25.0;
			}
		}
		
		flow of sourceWater : Water
			from waterSource.outletPort.waterOut to treadlePump.sourcePort.waterIn;
		
		part treadlePump : TreadlePumpAssembly {
			attribute :>> designFlowRate = 25.0;
			attribute :>> maxLiftHeight = 7.0;
			attribute :>> efficiency = 0.75;
			
			part :>> leftTreadle {
				attribute :>> treadleLength = 0.6;
				attribute :>> leverageRatio = 3.5;
				attribute :>> currentAngle = 0.0;
				attribute :>> maxAngle = 45.0;
			}
			
			part :>> rightTreadle {
				attribute :>> treadleLength = 0.6;
				attribute :>> leverageRatio = 3.5;
				attribute :>> currentAngle = 0.0;
				attribute :>> maxAngle = 45.0;
			}
			
			part :>> leftChamber {
				attribute :>> diameter = 0.08;
				attribute :>> strokeLength = 0.15;
				attribute :>> currentPosition = 0.0;
				attribute :>> chamberVolume = 0.75;
			}
			
			part :>> rightChamber {
				attribute :>> diameter = 0.08;
				attribute :>> strokeLength = 0.15;
				attribute :>> currentPosition = 0.0;
				attribute :>> chamberVolume = 0.75;
			}
			
			part :>> leftInletValve {
				attribute :>> crackingPressure = 100.0;
				attribute :>> isOpen = false;
			}
			
			part :>> rightInletValve {
				attribute :>> crackingPressure = 100.0;
				attribute :>> isOpen = false;
			}
			
			part :>> leftOutletValve {
				attribute :>> crackingPressure = 200.0;
				attribute :>> isOpen = false;
			}
			
			part :>> rightOutletValve {
				attribute :>> crackingPressure = 200.0;
				attribute :>> isOpen = false;
			}
			
			perform action pumpCycle : PumpingCycle {
				in operatorForce = operatorInput.appliedForce;
				out deliveredWater : Water;
				out actualFlowRate : FlowRate;
			}
			
			exhibit state operatingState : PumpOperatingStates {
				attribute :>> operatorForce = operatorInput.appliedForce;
			}
		}
		
		flow of deliveredWater : Water
			from treadlePump.deliveryPort.waterOut to deliveryTank.inletPort.waterIn;
		
		part deliveryTank : DeliveryTank {
			attribute :>> waterLevel = 0.0;
			attribute :>> tankCapacity = 1000.0;
			
			flow inletPort.waterIn to storedWater;
			
			item :>> storedWater {
				attribute :>> volume = 0.0;
				attribute :>> pressure = 0.0;
				attribute :>> temperature = 25.0;
			}
		}
		
		requirement flowRateReq : FlowRateRequirement {
			attribute :>> minimumFlowRate = 20.0;
			attribute :>> operatingFrequency = 0.5;
			
			satisfy by treadlePump.pumpCycle;
		}
		
		requirement liftHeightReq : LiftHeightRequirement {
			attribute :>> maximumLiftHeight = 7.0;
			
			satisfy by treadlePump;
		}
		
		requirement durabilityReq : DurabilityRequirement {
			attribute :>> minimumCycles = 50000.0;
			
			satisfy by treadlePump;
		}
		
		requirement efficiencyReq : EfficiencyRequirement {
			attribute :>> minimumEfficiency = 0.65;
			
			satisfy by treadlePump;
		}
		
		requirement backflowPreventionReq : BackflowPreventionRequirement {
			satisfy by treadlePump.leftInletValve, treadlePump.rightInletValve,
			          treadlePump.leftOutletValve, treadlePump.rightOutletValve;
		}
		
		assert constraint systemConstraint {
			treadlePump.efficiency >= 0.65 &
			treadlePump.maxLiftHeight >= 7.0 &
			treadlePump.designFlowRate >= 20.0
		}
	}
}
