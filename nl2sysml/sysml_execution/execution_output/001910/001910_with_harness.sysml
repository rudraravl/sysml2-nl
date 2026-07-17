package ChernobylRBMKReactorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ReactivityCoefficient :> Real;
	attribute def NeutronFluxLevel :> Real;
	attribute def XenonPoisonLevel :> Real;
	attribute def VoidFraction :> Real;
	attribute def RodInsertionDepth :> LengthValue;
	
	attribute def OperatorCommand;
	attribute def SafetySignal;
	attribute def AlarmCondition;
	
	value def ReactorState {
		attribute powerLevel : PowerValue;
		attribute coreTemperature : ThermodynamicTemperatureValue;
		attribute coolantPressure : PressureValue;
		attribute steamVoidFraction : VoidFraction;
	}
	
	port def CoolantPort {
		in flowRate : VolumeFlowRateValue;
		in temperature : ThermodynamicTemperatureValue;
		out pressure : PressureValue;
	}
	
	port def SteamPort {
		out flowRate : MassFlowRateValue;
		out temperature : ThermodynamicTemperatureValue;
		out pressure : PressureValue;
	}
	
	port def ElectricalPort {
		out power : PowerValue;
		out voltage : ISQ::ElectricPotentialValue;
	}
	
	port def ControlPort {
		in command : OperatorCommand;
		in emergencySignal : SafetySignal;
		out status : ReactorState;
	}
	
	part def RBMK1000ReactorCore {
		attribute thermalPower : PowerValue;
		attribute coreTemperature : ThermodynamicTemperatureValue;
		attribute neutronFlux : NeutronFluxLevel;
		attribute positiveVoidCoefficient : ReactivityCoefficient;
		attribute xenonConcentration : XenonPoisonLevel;
		attribute fuelChannels : Integer = 1661;
		
		port coolantIn : CoolantPort;
		port steamOut : SteamPort;
		port control : ControlPort;
	}
	
	part def ControlRodAssembly {
		attribute totalRods : Integer = 211;
		attribute insertedRods : Integer;
		attribute rodPosition : RodInsertionDepth[211];
		attribute graphiteDisplacerLength : LengthValue = 1.25[SI::m];
		attribute boronCarbideLength : LengthValue = 5.0[SI::m];
		attribute insertionSpeed : SpeedValue = 0.4[SI::m/SI::s];
		
		port control : ControlPort;
	}
	
	part def PrimaryCoolantCircuit {
		attribute numberOfLoops : Integer = 2;
		attribute flowRate : VolumeFlowRateValue;
		attribute inletTemperature : ThermodynamicTemperatureValue;
		attribute outletTemperature : ThermodynamicTemperatureValue;
		attribute operatingPressure : PressureValue = 7.0e6[SI::Pa];
		attribute voidContent : VoidFraction;
		
		port coolantSupply : CoolantPort;
		port steamGeneration : SteamPort;
	}
	
	part def SteamSeparatorDrum {
		attribute drumPressure : PressureValue;
		attribute waterLevel : LengthValue;
		attribute steamQuality : Real;
		
		port steamIn : SteamPort;
		port steamOut : SteamPort;
	}
	
	part def TurbineGeneratorSet {
		attribute numberOfTurbines : Integer = 2;
		attribute ratedPower : PowerValue = 500.0e6[SI::W];
		attribute rotationalSpeed : AngularVelocityValue = 314.159[SI::rad/SI::s];
		attribute coastdownTime : TimeValue;
		
		port steamIn : SteamPort;
		port electricalOut : ElectricalPort;
	}
	
	part def EmergencyProtectionSystem {
		attribute scramActivated : Boolean;
		attribute powerLimitExceeded : Boolean;
		attribute coolantFlowLow : Boolean;
		attribute reactorPeriodShort : Boolean;
		
		port monitoring : ControlPort;
		port rodControl : ControlPort;
	}
	
	part def OperatorControlRoom {
		attribute manualControlEnabled : Boolean;
		attribute safetySystemsOverridden : Boolean;
		attribute testProcedureActive : Boolean;
		
		port reactorControl : ControlPort;
	}
	
	requirement def SafeOperatingEnvelope {
		doc /* The reactor shall operate within the safe power range to prevent 
		     positive reactivity feedback from void formation. */
		subject reactor : RBMK1000ReactorCore;
		require constraint {
			reactor.thermalPower >= 700.0e6[SI::W] and reactor.thermalPower <= 3200.0e6[SI::W]
		}
	}
	
	requirement def VoidCoefficientControl {
		doc /* The positive void coefficient of reactivity shall be compensated 
		     by adequate control rod insertion to prevent power excursion. */
		subject coolant : PrimaryCoolantCircuit;
		subject rods : ControlRodAssembly;
		require constraint {
			coolant.voidContent < 0.5 or rods.insertedRods >= 30
		}
	}
	
	requirement def ControlRodSafety {
		doc /* Control rod design shall not introduce positive reactivity during 
		     emergency insertion due to graphite displacer displacement effect. */
		subject rods : ControlRodAssembly;
		require constraint {
			rods.graphiteDisplacerLength <= 1.5[SI::m]
		}
	}
	
	requirement def XenonTransientManagement {
		doc /* Xenon-135 poisoning shall be managed to prevent reactor stall 
		     and subsequent power instability during recovery. */
		subject reactor : RBMK1000ReactorCore;
		require constraint {
			reactor.xenonConcentration < 0.9 or reactor.thermalPower > 1600.0e6[SI::W]
		}
	}
	
	requirement def SafetySystemAvailability {
		doc /* Emergency protection systems shall remain active and not be 
		     bypassed during reactor operation or testing. */
		subject controlRoom : OperatorControlRoom;
		require constraint {
			controlRoom.safetySystemsOverridden == false
		}
	}
	
	requirement <'RBMK-SAFETY-001'> reactorSafetyRequirement {
		doc /* The RBMK-1000 reactor shall maintain stable operation and respond 
		     to emergency conditions without catastrophic failure. */
		assume constraint {
			true
		}
		require safeOp : SafeOperatingEnvelope;
		require voidCtrl : VoidCoefficientControl;
		require rodSafety : ControlRodSafety;
		require xenonMgmt : XenonTransientManagement;
		require safetyAvail : SafetySystemAvailability;
	}
	
	action def MonitorReactorParameters {
		out powerLevel : PowerValue;
		out coreTemp : ThermodynamicTemperatureValue;
		out neutronFlux : NeutronFluxLevel;
		out coolantFlow : VolumeFlowRateValue;
		out voidFraction : VoidFraction;
		out xenonLevel : XenonPoisonLevel;
		out rodPosition : Integer;
	}
	
	action def AdjustControlRods {
		in targetPosition : RodInsertionDepth;
		in currentPosition : RodInsertionDepth;
		in emergencyScram : Boolean;
		out newPosition : RodInsertionDepth;
		out reactivityChange : ReactivityCoefficient;
		out graphiteTipEffect : ReactivityCoefficient;
	}
	
	action def RegulateCoolantFlow {
		in targetFlow : VolumeFlowRateValue;
		in currentFlow : VolumeFlowRateValue;
		in pumpStatus : Boolean[4];
		out actualFlow : VolumeFlowRateValue;
		out pressureChange : PressureValue;
	}
	
	action def InitiateEmergencyShutdown {
		in triggerCondition : AlarmCondition;
		out scramSignal : Boolean;
		out rodInsertionCommand : RodInsertionDepth;
	}
	
	action def ManageReactorOperation {
		in operatingMode : String;
		in targetPower : PowerValue;
		in testMode : Boolean;
		out systemStatus : String;
		
		first start;
		then merge steadyStateOperation;
		
		then action monitorState : MonitorReactorParameters {
			out currentPower : PowerValue;
			out currentTemp : ThermodynamicTemperatureValue;
			out currentNeutronFlux : NeutronFluxLevel;
			out currentCoolantFlow : VolumeFlowRateValue;
			out currentVoidFraction : VoidFraction;
			out currentXenon : XenonPoisonLevel;
			out currentRodPosition : Integer;
		}
		
		then decide operatingCondition;
			if testMode and monitorState.currentPower < 700.0e6[SI::W] then enterInstabilityRegion;
			if monitorState.currentPower > 3200.0e6[SI::W] then initiateScram;
			if monitorState.currentVoidFraction > 0.6 then initiateScram;
			if monitorState.currentPower >= 700.0e6[SI::W] and monitorState.currentPower <= 3200.0e6[SI::W] then normalOperation;
		
		action enterInstabilityRegion {
			doc /* Operating below minimum controlled power with xenon poisoning 
			     creates unstable conditions. Operators disabled safety systems 
			     to continue turbine coastdown test. */
			
			action disableSafetyInterlocks {
				doc /* Emergency core cooling system disabled, multiple safety 
				     systems bypassed per test procedure. */
			}
			
			then action withdrawControlRods : AdjustControlRods {
				in targetPosition = 7.0[SI::m];
				in currentPosition = 3.0[SI::m];
				in emergencyScram = false;
				out newPosition : RodInsertionDepth;
				out reactivityChange : ReactivityCoefficient;
				out graphiteTipEffect : ReactivityCoefficient;
			}
			
			then action reduceCoolantFlow : RegulateCoolantFlow {
				in targetFlow = 50.0[SI::m^3/SI::s];
				in currentFlow = 80.0[SI::m^3/SI::s];
				in pumpStatus = (true, true, false, false);
				out actualFlow : VolumeFlowRateValue;
				out pressureChange : PressureValue;
			}
			
			then action steamVoidFormation {
				doc /* Reduced coolant flow causes boiling and steam void formation 
				     in fuel channels. */
			}
			
			then action positiveReactivityInsertion {
				doc /* Positive void coefficient causes reactivity increase as steam 
				     voids displace water moderator. */
			}
			
			then action powerSurgeDetected {
				doc /* Rapid uncontrolled power increase detected, operators attempt 
				     emergency shutdown. */
			}
			
			then action attemptEmergencyScram : InitiateEmergencyShutdown {
				in triggerCondition : AlarmCondition;
				out scramSignal = true;
				out rodInsertionCommand = 0.0[SI::m];
			}
			
			then action controlRodInsertion : AdjustControlRods {
				in targetPosition = 0.0[SI::m];
				in currentPosition = 7.0[SI::m];
				in emergencyScram = true;
				out newPosition : RodInsertionDepth;
				out reactivityChange : ReactivityCoefficient;
				out graphiteTipEffect = 1.0;
			}
			
			then action graphiteDisplacerEffect {
				doc /* Graphite tips of control rods displace water before boron 
				     absorber enters core, causing brief positive reactivity spike. */
			}
			
			then action promptCriticalityExcursion {
				doc /* Combined positive reactivity from voids and graphite tips 
				     causes prompt supercritical power excursion to ~33,000 MW. */
			}
			
			then action fuelFragmentation {
				doc /* Extreme power density causes fuel pellet fragmentation and 
				     rapid heat transfer to coolant. */
			}
			
			then action steamExplosion {
				doc /* Rapid steam generation causes first explosion, destroying 
				     fuel channels and lifting reactor lid. */
			}
			
			then action graphiteFireIgnition {
				doc /* Exposed graphite moderator ignites in air, releasing massive 
				     radioactive contamination. */
			}
			
			then action secondExplosion {
				doc /* Hydrogen and carbon monoxide explosion further destroys 
				     reactor structure. */
			}
		}
		then catastrophicFailure;
		
		action normalOperation {
			action maintainControlRods : AdjustControlRods {
				in targetPosition = 4.0[SI::m];
				in currentPosition : RodInsertionDepth;
				in emergencyScram = false;
				out newPosition : RodInsertionDepth;
				out reactivityChange : ReactivityCoefficient;
				out graphiteTipEffect : ReactivityCoefficient;
			}
			
			then action maintainCoolantFlow : RegulateCoolantFlow {
				in targetFlow = 80.0[SI::m^3/SI::s];
				in currentFlow : VolumeFlowRateValue;
				in pumpStatus = (true, true, true, true);
				out actualFlow : VolumeFlowRateValue;
				out pressureChange : PressureValue;
			}
		}
		then steadyStateOperation;
		
		action initiateScram : InitiateEmergencyShutdown {
			in triggerCondition : AlarmCondition;
			out scramSignal : Boolean;
			out rodInsertionCommand : RodInsertionDepth;
		}
		then controlledShutdown;
		
		action catastrophicFailure {
			doc /* Reactor core destroyed, containment breached, massive radioactive 
			     release to environment. */
		}
		then done;
		
		action controlledShutdown {
			doc /* Reactor safely shut down within design limits. */
		}
		then done;
	}
	
	part chernobylUnit4 : RBMK1000ReactorCore {
		attribute :>> thermalPower = 3200.0e6[SI::W];
		attribute :>> coreTemperature = 600.0[SI::K];
		attribute :>> positiveVoidCoefficient = 4.7;
		attribute :>> xenonConcentration = 0.8;
		
		perform action reactorOperation : ManageReactorOperation {
			in operatingMode = "Test";
			in targetPower = 700.0e6[SI::W];
			in testMode = true;
			out systemStatus;
		}
		
		part controlRods : ControlRodAssembly {
			attribute :>> insertedRods = 6;
			perform reactorOperation.enterInstabilityRegion.withdrawControlRods;
			perform reactorOperation.enterInstabilityRegion.controlRodInsertion;
			perform reactorOperation.normalOperation.maintainControlRods;
		}
		
		part primaryCoolant : PrimaryCoolantCircuit {
			attribute :>> flowRate = 80.0[SI::m^3/SI::s];
			attribute :>> inletTemperature = 543.0[SI::K];
			attribute :>> outletTemperature = 557.0[SI::K];
			attribute :>> voidContent = 0.15;
			perform reactorOperation.enterInstabilityRegion.reduceCoolantFlow;
			perform reactorOperation.normalOperation.maintainCoolantFlow;
		}
		
		part steamDrum : SteamSeparatorDrum {
			attribute :>> drumPressure = 7.0e6[SI::Pa];
			attribute :>> steamQuality = 0.14;
		}
		
		part turbineGenerator : TurbineGeneratorSet {
			attribute :>> ratedPower = 1000.0e6[SI::W];
			attribute :>> coastdownTime = 50.0[SI::s];
		}
		
		part emergencySystem : EmergencyProtectionSystem {
			attribute :>> scramActivated = false;
			attribute :>> powerLimitExceeded = false;
			perform reactorOperation.enterInstabilityRegion.attemptEmergencyScram;
			perform reactorOperation.initiateScram;
		}
		
		part controlRoom : OperatorControlRoom {
			attribute :>> manualControlEnabled = true;
			attribute :>> safetySystemsOverridden = true;
			attribute :>> testProcedureActive = true;
		}
		
		connect primaryCoolant.coolantSupply to coolantIn;
		connect primaryCoolant.steamGeneration to steamDrum.steamIn;
		connect steamDrum.steamOut to turbineGenerator.steamIn;
		connect controlRoom.reactorControl to control;
		connect emergencySystem.rodControl to controlRods.control;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ChernobylRBMKReactorSystem::*;

    action orchestrator {
        attribute testTargetPosition : RodInsertionDepth;
        attribute testCurrentPosition : RodInsertionDepth;
        action maintainControlRodsProbe : AdjustControlRods {
            in targetPosition = testTargetPosition;
            in currentPosition = testCurrentPosition;
            in emergencyScram = false;
        }
        first maintainControlRodsProbe;
    }
}
