package 'Vacuum Extraction System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VacuumPressureValue :> ISQ::PressureValue;
	attribute def AirFlowRateValue :> ISQ::VolumeFlowRateValue;
	attribute def FilterEfficiencyValue :> Real;
	attribute def ContainerFillLevelValue :> Real;
	
	item def Debris;
	item def Dust;
	item def CleanAir;
	item def ContaminatedAir {
		attribute airComponent : CleanAir;
		attribute debrisContent : Debris[*];
		attribute dustContent : Dust[*];
	}
	
	attribute def SystemCommand;
	attribute def PowerOnCommand :> SystemCommand;
	attribute def PowerOffCommand :> SystemCommand;
	attribute def FilterReplacedEvent :> SystemCommand;
	attribute def ContainerEmptiedEvent :> SystemCommand;
	
	port def IntakePort {
		in item contaminatedAir : ContaminatedAir;
	}
	
	port def ExhaustPort {
		out item cleanAir : CleanAir;
	}
	
	port def PowerPort {
		in attribute powerSupply : ISQ::PowerValue;
	}
	
	port def DebrisPort {
		in item debris : Debris;
		in item dust : Dust;
	}
	
	part def ElectricMotor {
		port powerIn : PowerPort;
		attribute motorSpeed : ISQ::AngularVelocityValue;
		attribute operatingPower : ISQ::PowerValue;
		
		action def RunMotor {
			in power : ISQ::PowerValue;
			out speed : ISQ::AngularVelocityValue;
		}
	}
	
	part def ImpellerFan {
		attribute rotationSpeed : ISQ::AngularVelocityValue;
		attribute generatedVacuum : VacuumPressureValue;
		
		action def GenerateVacuum {
			in speed : ISQ::AngularVelocityValue;
			out vacuumPressure : VacuumPressureValue;
			out airflow : AirFlowRateValue;
		}
	}
	
	part def IntakeNozzle {
		port intake : IntakePort;
		attribute nozzleDiameter : ISQ::LengthValue;
		
		action def IngestMaterial {
			in vacuumPressure : VacuumPressureValue;
			in airflow : AirFlowRateValue;
			out ingestedAir : ContaminatedAir;
		}
	}
	
	part def FilterAssembly {
		attribute filterEfficiency : FilterEfficiencyValue;
		attribute currentLoad : ContainerFillLevelValue;
		attribute maxCapacity : ISQ::MassValue;
		
		action def SeparateContaminants {
			in contaminatedAir : ContaminatedAir;
			out cleanAir : CleanAir;
			out separatedDebris : Debris[*];
			out separatedDust : Dust[*];
		}
		
		state filterLifecycle {
			entry; then clean;
			
			state clean {
				doc /* Filter is operating at optimal efficiency */
			}
			
			transition cleanToPartiallyLoaded
				first clean
				accept when currentLoad >= 0.3
				then partiallyLoaded;
			
			state partiallyLoaded {
				doc /* Filter is accumulating material but still effective */
			}
			
			transition partiallyLoadedToSaturated
				first partiallyLoaded
				accept when currentLoad >= 0.85
				then saturated;
			
			state saturated {
				doc /* Filter requires replacement */
			}
			
			transition saturatedToClean
				first saturated
				accept at FilterReplacedEvent
				then clean;
		}
	}
	
	part def CollectionContainer {
		port debrisIn : DebrisPort;
		attribute capacity : ISQ::VolumeValue;
		attribute currentFillLevel : ContainerFillLevelValue;
		
		action def StoreDebris {
			in debris : Debris[*];
			in dust : Dust[*];
			out storedMaterial : Debris[*];
		}
		
		state containerStatus {
			entry; then empty;
			
			state empty {
				doc /* Container is ready to receive material */
			}
			
			transition emptyToFilling
				first empty
				accept when currentFillLevel >= 0.1
				then filling;
			
			state filling {
				doc /* Container is accumulating debris */
			}
			
			transition fillingToFull
				first filling
				accept when currentFillLevel >= 0.9
				then full;
			
			state full {
				doc /* Container requires emptying */
			}
			
			transition fullToEmpty
				first full
				accept at ContainerEmptiedEvent
				then empty;
		}
	}
	
	part def ExhaustSystem {
		port exhaust : ExhaustPort;
		
		action def DischargeCleanAir {
			in cleanAir : CleanAir;
			out exhaustedAir : CleanAir;
		}
	}
	
	part def ControlUnit {
		attribute targetVacuumPressure : VacuumPressureValue;
		attribute currentVacuumPressure : VacuumPressureValue;
		attribute systemOperational : Boolean;
		
		action def MonitorAndControl {
			in vacuumPressure : VacuumPressureValue;
			in filterLoad : ContainerFillLevelValue;
			in containerFill : ContainerFillLevelValue;
			out motorPowerCommand : ISQ::PowerValue;
			out operationalStatus : Boolean;
		}
		
		state operationalMode {
			entry; then standby;
			
			state standby {
				doc /* System is powered but not extracting */
			}
			
			transition standbyToStartup
				first standby
				accept at PowerOnCommand
				then startup;
			
			state startup {
				doc /* System is initializing vacuum generation */
			}
			
			transition startupToOperating
				first startup
				accept when currentVacuumPressure <= targetVacuumPressure * 0.85
				then operating;
			
			state operating {
				entry; then normalOperation;
				
				state normalOperation {
					doc /* System is extracting at full capacity */
				}
				
				transition normalToReduced
					first normalOperation
					accept when filterLoad >= 0.75
					then reducedPower;
				
				state reducedPower {
					doc /* System is operating at reduced capacity due to filter load */
				}
				
				transition reducedToNormal
					first reducedPower
					accept when filterLoad < 0.6
					then normalOperation;
			}
			
			transition operatingToShutdown
				first operating
				accept at PowerOffCommand
				then shutdown;
			
			state shutdown {
				doc /* System is powering down */
			}
			
			transition shutdownToStandby
				first shutdown
				then standby;
		}
	}
	
	part def VacuumExtractionSystem {
		part motor : ElectricMotor;
		part impeller : ImpellerFan;
		part nozzle : IntakeNozzle;
		part filterAssy : FilterAssembly;
		part container : CollectionContainer;
		part exhaustSys : ExhaustSystem;
		part controller : ControlUnit;
		
		port powerInput : PowerPort;
		port materialIntake : IntakePort;
		port airExhaust : ExhaustPort;
		
		connect powerInput to motor.powerIn;
		connect nozzle.intake to materialIntake;
		connect exhaustSys.exhaust to airExhaust;
		
		action extractContaminants {
			doc /* Primary function: Extract debris and dust from environment by creating vacuum,
			       ingesting contaminated air, separating contaminants through filtration,
			       storing collected material, and exhausting clean air */
			
			first start;
			
			then action initializePower {
				action supplyPower {
					out power : ISQ::PowerValue;
				}
				flow supplyPower.power to driveMotor.power;
				
				action driveMotor : ElectricMotor::RunMotor {
					in power : ISQ::PowerValue;
					out speed : ISQ::AngularVelocityValue;
				}
			}
			
			then action generateVacuum : ImpellerFan::GenerateVacuum {
				in speed : ISQ::AngularVelocityValue = initializePower.driveMotor.speed;
				out vacuumPressure : VacuumPressureValue;
				out airflow : AirFlowRateValue;
			}
			
			then merge continuousOperation;
			
			then action ingestMaterial : IntakeNozzle::IngestMaterial {
				in vacuumPressure : VacuumPressureValue = generateVacuum.vacuumPressure;
				in airflow : AirFlowRateValue = generateVacuum.airflow;
				out ingestedAir : ContaminatedAir;
			}
			
			then action separateContaminants : FilterAssembly::SeparateContaminants {
				in contaminatedAir : ContaminatedAir = ingestMaterial.ingestedAir;
				out cleanAir : CleanAir;
				out separatedDebris : Debris[*];
				out separatedDust : Dust[*];
			}
			
			then action storeAndExhaust {
				action storeDebris : CollectionContainer::StoreDebris {
					in debris : Debris[*] = separateContaminants.separatedDebris;
					in dust : Dust[*] = separateContaminants.separatedDust;
					out storedMaterial : Debris[*];
				}
				
				action dischargeAir : ExhaustSystem::DischargeCleanAir {
					in cleanAir : CleanAir = separateContaminants.cleanAir;
					out exhaustedAir : CleanAir;
				}
			}
			
			then action monitorSystem : ControlUnit::MonitorAndControl {
				in vacuumPressure : VacuumPressureValue = generateVacuum.vacuumPressure;
				in filterLoad : ContainerFillLevelValue = filterAssy.currentLoad;
				in containerFill : ContainerFillLevelValue = container.currentFillLevel;
				out motorPowerCommand : ISQ::PowerValue;
				out operationalStatus : Boolean;
			}
			
			then decide;
				if monitorSystem.operationalStatus then continuousOperation;
				if not monitorSystem.operationalStatus then shutdownSystem;
			
			action shutdownSystem;
			then done;
		}
	}
	
	part vacuumExtractionSystem : VacuumExtractionSystem;
	
	requirement def VacuumPerformanceRequirement {
		doc /* The vacuum extraction system shall maintain sufficient negative pressure
		       to effectively extract debris and dust from the target environment */
		subject system : VacuumExtractionSystem;
		require constraint {
			system.impeller.generatedVacuum <= -6000.0 [SI::Pa]
		}
	}
	
	requirement def FiltrationEfficiencyRequirement {
		doc /* The filter assembly shall maintain filtration efficiency above 98%
		       when operating below 80% capacity */
		subject filterUnit : FilterAssembly;
		require constraint {
			filterUnit.currentLoad < 0.8 implies filterUnit.filterEfficiency >= 0.98
		}
	}
	
	requirement def ContainerCapacityRequirement {
		doc /* The collection container shall provide adequate storage capacity
		       and alert when approaching full capacity */
		subject containerUnit : CollectionContainer;
		require constraint {
			containerUnit.currentFillLevel < 0.95
		}
	}
	
	requirement <'VES-SYS-001'> systemFunctionalRequirement {
		doc /* The vacuum extraction system shall continuously extract debris and dust
		       from the environment by generating negative pressure, ingesting contaminated air
		       through an intake nozzle, separating contaminants via filtration, storing collected
		       material in a container, and exhausting filtered clean air to the environment */
		
		subject ves : VacuumExtractionSystem;
		
		assume constraint { 
			ves.powerInput.powerSupply >= 800.0 [SI::W]
		}
		
		require VacuumPerformanceRequirement { 
			subject system = ves; 
		}
		
		require FiltrationEfficiencyRequirement { 
			subject filterUnit = ves.filterAssy; 
		}
		
		require ContainerCapacityRequirement { 
			subject containerUnit = ves.container; 
		}
	}
}
